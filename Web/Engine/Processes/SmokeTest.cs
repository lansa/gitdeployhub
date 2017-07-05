using System;
using System.Text.RegularExpressions;
using System.Web;

namespace GitDeployHub.Web.Engine.Processes
{
    public class SmokeTest : BaseProcess
    {
        public SmokeTest(Hub hub, Instance instance)
            : base(hub, instance)
        {
        }

        protected override void DoExecute()
        {
            Log("Smoke Testing " + Instance.Name);
            Instance.ExecuteSmokeTest(this);
            Log("Instance Smoke Tested " + Instance.Name);
            Instance.LastSmokeTest = this;
        }
    }
}
