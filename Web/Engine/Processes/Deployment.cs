using System;

namespace GitDeployHub.Web.Engine.Processes
{
    public class Deployment : Fetch
    {
        public bool Dry { get; set; }

        public Deployment(Hub hub, Instance instance)
            : base(hub, instance)
        {
        }

        protected override void DoExecute()
        {
            Log("Deploying " + Instance.Name);

            // Parameters may be referenced here like this: Log("User ID: " + Parameters["UserID"] );

            // Doing a Fetch and a Pull causes 2 connections to the origin to be made. This is far slower than the rest of the 
            // processing, and is a special case anyway, as this task will usually be caused by a commit to origin
            // base.DoExecute();
            //if (Instance.FilesChangedToTreeish.Length > 0)
            if ( true )
            {
                if (!Dry)
                {
                    Instance.ExecutePreDeploy(this);
                    Instance.ResetHard(this);         // Clean out all local changes from the directory, there should be none and the 1st install via MSI leaves files in the Package Directory, of course
                    Instance.Pull(this);             
                    Instance.ExecutePostDeploy(this);
                    Log("Instance Deployed: " + Instance.Name);
                    Instance.LastDeployment = this;
                }
            }
            else
            {
                Skipped = true;
                Log("Skipping deployment.");
                LogNewLine();
            }
        }

    }
}
