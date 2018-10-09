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
            if (!Dry)
            {
               Instance.ResetHard(this, true);   // Attempt to get the latest changes in order to update predeploy.ps1 BEFORE running it, and there may be errors due to locked files. Ignore them.

               Instance.ExecutePreDeploy(this);
               Instance.ResetHard(this);         // Clean out all local changes from the directory, there should be none and the 1st install via MSI leaves files in the Package Directory, of course
               // Instance.Pull(this);           // Not required as reset to origin's state which is same as a pull
               Instance.ExecutePostDeploy(this);
               Log("Instance Deployed: " + Instance.Name);
               Instance.LastDeployment = this;
            }
            else
            {
               Instance.Fetch(this);
            }
        }
    }
}
