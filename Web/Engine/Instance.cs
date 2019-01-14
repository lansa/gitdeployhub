﻿using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;
using GitDeployHub.Web.Engine.Notifiers;
using GitDeployHub.Web.Engine.Processes;
using Microsoft.Win32;

namespace GitDeployHub.Web.Engine
{
    public class Instance
    {
        public string Name { get; private set; }

        public string Folder { get; set; }

        public IDictionary<string, string> EnvironmentVariables { get; set; }

        public string Treeish { get; set; }

        public string ProjectFolder { get; set; }

        private static string _mappedApplicationPath;

        public static string MappedApplicationPath
        {
            get
            {
                if (_mappedApplicationPath == null)
                {
                    var appPath = HttpContext.Current.Request.ApplicationPath.ToLower();
                    if (appPath == "/")
                    {
                        //a site
                        appPath = "/";
                    }
                    else if (!appPath.EndsWith(@"/"))
                    {
                        //a virtual
                        appPath += @"/";
                    }
                    var mappedPath = HttpContext.Current.Server.MapPath(appPath);
                    if (!mappedPath.EndsWith(@"\"))
                        mappedPath += @"\";
                    _mappedApplicationPath = mappedPath;
                }
                return _mappedApplicationPath;
            }
        }

        public Deployment LastDeployment { get; set; }

        public SmokeTest LastSmokeTest { get; set; }

        public BaseProcess CurrentProcess { get; set; }

        public Hub Hub { get; set; }

        private string[] _tags;

        public string[] Tags
        {
            get
            {
                if (_tags == null)
                {
                    try
                    {
                        var log = new StringLog();
                        if (!HasFolder(".git"))
                        {
                            _tags = new[] { "<not-a-git-repo>" };
                        }
                        else
                        {
                            ExecuteProcess("git", "log -n1 --pretty=format:%d", log, false);
                            _tags = log.Output.Trim(new[] { ' ', '(', ')', '\r', '\n' })
                                       .Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries)
                                       .Select(t => t.Trim())
                                       .Where(t => t != "HEAD" && t != "master" && !t.StartsWith("origin/"))
                                       .ToArray();
                        }
                    }
                    catch
                    {
                        _tags = new[] { "<error-getting-tags>" };
                    }
                }
                return _tags;
            }
        }

        private string[] _filesChangedToTreeish;

        public string[] FilesChangedToTreeish
        {
            get
            {
                if (_filesChangedToTreeish == null)
                {
                    var log = new StringLog();
                    try
                    {
                        Diff(log, Treeish, out _filesChangedToTreeish, false);
                    }
                    catch (Exception ex)
                    {
                        _filesChangedToTreeish = new[] { "<error getting diff: " + ex.Message + ">" };
                    }
                }
                return _filesChangedToTreeish;
            }
        }

        private string[] _changeLog;

        public string[] ChangeLog
        {
            get
            {
                if (_changeLog == null)
                {
                    _changeLog = new[] { " *No ChangeLog Found*" };
                    var changeLogFilenames = new[] { "CHANGELOG.md", "CHANGELOG.txt", "CHANGELOG" };
                    foreach (var changeLogFilename in changeLogFilenames)
                    {
                        var fullName = Path.Combine(Folder, changeLogFilename);
                        if (File.Exists(fullName))
                        {
                            _changeLog = File.ReadLines(fullName).ToArray();
                        }
                    }
                }
                return _changeLog;
            }
        }

        /// <summary>
        /// Get short version of ChangeLog
        /// </summary>
        public string[] ChangeLogShort
        {
            get
            {
                var changeLog = ChangeLog;
                var versionsRemaining = 3;
                var output = new List<string>();
                var versionTitle = new Regex("^\\s*#*\\s*v?\\d+\\.\\d+", RegexOptions.Compiled);
                foreach (var line in changeLog)
                {
                    if (versionTitle.IsMatch(line))
                    {
                        versionsRemaining--;
                    }
                    if (versionsRemaining < 0)
                    {
                        break;
                    }
                    output.Add(line);
                }
                return output.ToArray();
            }
        }

        /// <summary>
        /// Get only last version in ChangeLog
        /// </summary>
        public string[] ChangeLogLast
        {
            get
            {
                var changeLog = ChangeLog;
                var versionsRemaining = 1;
                var output = new List<string>();
                var versionTitle = new Regex("^\\s*#*\\s*v?\\d+\\.\\d+", RegexOptions.Compiled);
                var onHeader = true;
                foreach (var line in changeLog)
                {
                    if (versionTitle.IsMatch(line))
                    {
                        onHeader = false;
                        versionsRemaining--;
                    }
                    if (versionsRemaining < 0)
                    {
                        break;
                    }
                    if (!onHeader)
                    {
                        output.Add(line);
                    }
                }
                return output.ToArray();
            }
        }

        private bool? _hasSmokeTest;

        public bool HasSmokeTest
        {
            get
            {
                if (_hasSmokeTest == null)
                {
                    _hasSmokeTest = HasFile(Path.Combine(ProjectFolder, "autodeploy\\SmokeTest.ps1") );
                }
                if ( _hasSmokeTest == false)
                {
                    _hasSmokeTest = HasFile("autodeploy\\SmokeTest.ps1");
                }
                return _hasSmokeTest ?? false;
            }
        }

        public Notifier[] Notifiers { get; set; }

        public Instance(Hub hub, string name, string treeish = null, string folder = null, string projectFolder = null)
        {
            Hub = hub;
            Name = name;
            Treeish = treeish;
            Folder = folder;
            EnvironmentVariables = new Dictionary<string, string>();
            ProjectFolder = projectFolder;
            if (string.IsNullOrWhiteSpace(Folder))
            {
                if (Name == "_self")
                {
                    Folder = Path.GetFullPath(MappedApplicationPath);
                    if (!HasFile(".git"))
                    {
                        var gitFolder = Folder;
                        while (!string.IsNullOrEmpty(gitFolder))
                        {
                            gitFolder = Directory.GetParent(gitFolder).FullName;
                            if (Directory.Exists(Path.Combine(gitFolder, ".git")))
                            {
                                Folder = gitFolder;
                                break;
                            }
                        }
                    }
                }
                else
                {
                    Folder = Path.GetFullPath(Path.Combine(MappedApplicationPath, Path.Combine("../../", name)));
                }
            }
        }

        public Deployment CreateDeployment(IDictionary<string, string> parameters = null)
        {
            var deployment = new Deployment(Hub, this)
            {
                Parameters = parameters
            };
            Hub.Queue.Add(deployment);
            return deployment;
        }

        public SmokeTest CreateSmokeTest(IDictionary<string, string> parameters = null)
        {
            var smokeTest = new SmokeTest(Hub, this)
            {
                Parameters = parameters
            };
            Hub.Queue.Add(smokeTest);
            return smokeTest;
        }

        public void ExecuteProcess(string command, string arguments, ILog log, bool echo = true)
        {
            if (echo)
            {
                log.Log(string.Format("   Working Directory: {0}", Folder));
                log.Log(string.Format(" & {0} {1}", command, arguments ?? ""));
            }
            var processStartInfo = new ProcessStartInfo(command)
                {
                    UseShellExecute = false,
                    WorkingDirectory = Folder,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    WindowStyle = ProcessWindowStyle.Hidden
                };
            if (EnvironmentVariables != null)
            {
                foreach (var envVar in EnvironmentVariables)
                {
                    processStartInfo.EnvironmentVariables[envVar.Key] = envVar.Value;
                }
            }
            if (!string.IsNullOrWhiteSpace(arguments))
            {
                processStartInfo.Arguments = arguments;
            }

            var process = new System.Diagnostics.Process
                {
                    StartInfo = processStartInfo
                };
            process.OutputDataReceived += (sender, args) => log.Log(args.Data);
            process.ErrorDataReceived += (sender, args) => log.Log(args.Data);
            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();
            var exited = process.WaitForExit((int)TimeSpan.FromMinutes(15).TotalMilliseconds);
            if (!exited)
            {
                throw new Exception(string.Format("{0} {1} timed out.", command, arguments));
            }
            if (process.ExitCode != 0)
            {
                throw new Exception(string.Format("{0} {1} failed with exit code: {2}", command, arguments, process.ExitCode));
            }
        }

        private void FolderChanged()
        {
            _tags = null;
            _changeLog = null;
            _filesChangedToTreeish = null;
            _hasSmokeTest = null;
            LastSmokeTest = null;
        }

        public void Fetch(ILog log, bool fetchTags = true)
        {
            ExecuteProcess("git", "fetch --force", log);
            if (fetchTags)
            {
                ExecuteProcess("git", "fetch --tags --force", log);
            }
            ExecuteProcess("git", "status -uno", log);
            FolderChanged();
        }

        public void Status(ILog log, out bool isBehind, out bool canFastForward)
        {
            var commandLog = new StringLog(log);
            ExecuteProcess("git", "status -uno", commandLog);
            var statusOutput = commandLog.Output;
            isBehind = statusOutput.Contains("Your branch is behind");
            canFastForward = statusOutput.Contains("can be fast-forwarded");
        }

        public void Diff(ILog log, string treeish, out string[] changes, bool echo = true)
        {
            var commandLog = new StringLog(log);
            ExecuteProcess("git", "diff --name-only HEAD.." + treeish, commandLog, echo);
            var output = commandLog.Output;
            if (string.IsNullOrWhiteSpace(output))
            {
                changes = new string[0];
            }
            else
            {
                changes = output.Split(new[] { Environment.NewLine }, StringSplitOptions.RemoveEmptyEntries);
            }
        }

        public void Pull(ILog log)
        {
            ExecuteProcess("git", "pull", log);
            FolderChanged();
        }

        // Clear out any changes in the working directory so that the pull will always succeed
        public void ResetHard(ILog log, bool ignoreErrors = false)
        {
            log.Log(string.Format("new changes"));

            if (ProjectFolder.Length != 0)
            {
                ExecuteProcess("git", "clean -fd -- " + ProjectFolder + "\\", log); // Ensure there are no changes from the initial install in the project folder
            }

            // Must fetch the origin here so we can reset to the origin!
            Fetch(log);

            // Set all changes back to the origin's HEAD. Ensures that a force push to the origin also resets this repo to the exact same state
            // Also ensures that the current branch is set correctly - after reset --hard so that no complaints about merge conflicts and the like.
            var program = "powershell";
            var block = 
                "cmd /c exit 0;" +
                "&'git' reset --hard origin/" + Treeish +
                ";if ($LASTEXITCODE -gt 0 ) { exit $LASTEXITCODE }; " +
                "&'git' checkout -f " + Treeish +
                ";if ($LASTEXITCODE -gt 0 ) { exit $LASTEXITCODE }; ";
            if ( ignoreErrors )
            {
                try
                {
                    ExecuteProcess(program, block, log);
                }
                catch
                {
                    log.Log("WARNING: Error resetting. Probably due to locked files. Continuing");
                }
            }
            else
            {
                ExecuteProcess(program, block, log);
            }
            FolderChanged();
        }

        public void Stash(ILog log)
        {
            ExecuteProcess("git", "stash", log);
        }

        public void Checkout(string branchOrTag, ILog log)
        {
            ExecuteProcess("git", "checkout " + branchOrTag, log);
            FolderChanged();
        }

        public bool HasFile(string fileName)
        {
            return File.Exists(Path.Combine(Folder, fileName));
        }

        public bool HasFolder(string path)
        {
            return Directory.Exists(Path.Combine(Folder, path));
        }

        public void ExecuteIfExists(string fileName, string command, string arguments, ILog log)
        {
            if (!HasFile(fileName))
            {
                log.Log(string.Format("({0} not present)", fileName));
                return;
            }
            ExecuteProcess(command, arguments, log);
        }

        public void ExecuteScriptIfExists(string fileName, ILog log)
      {
            var commonFilename = fileName;
            var powershellPath = "powershell";

            if ( !Environment.Is64BitProcess )
            {
                powershellPath = Path.Combine(Environment.GetEnvironmentVariable("SystemRoot"), "sysnative\\WindowsPowershell\\v1.0\\powershell.exe");
            }

            // Execute a project-specific script, if it exists
            var projectFileName = Path.Combine(ProjectFolder, commonFilename);
            if (HasFile(projectFileName))
            {
               log.Log("Project-specific script file");
               ExecuteProcess(powershellPath, "-executionPolicy Bypass " + projectFileName, log);
            }
            else
            {
                log.Log(string.Format("({0} not present)", projectFileName));

                // Execute a common script, if it exists
                ExecuteIfExists(commonFilename, powershellPath, "-executionPolicy Bypass " + commonFilename, log);
            }            
        }

        public void ExecutePreDeploy(ILog log)
        {
            var filename = "autodeploy\\PreDeploy.ps1";
            ExecuteScriptIfExists(filename, log);
        }            

        public void ExecutePostDeploy(ILog log)
        {
            var fileName = "autodeploy\\PostDeploy.ps1";
            ExecuteScriptIfExists(fileName, log);
        }

        public void ExecuteSmokeTest(ILog log)
        {
            var fileName = "autodeploy\\SmokeTest.ps1";
            ExecuteScriptIfExists(fileName, log);
        }

        internal void Log(string message, BaseProcess process)
        {
            Hub.Log(message, this, process);
        }

    }
}
