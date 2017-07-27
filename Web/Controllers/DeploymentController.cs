﻿using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Linq;
using System.Net;
using System.Web;
using System.Web.Mvc;
using GitDeployHub.Web.Engine;

namespace GitDeployHub.Web.Controllers
{
    public class DeploymentController : Controller
    {
        // POST /deployment/start/instance-name
        [AcceptVerbs("POST", "PUT")]
        public ActionResult Start(string id, string source = null, bool dry = false)
        {
            var httpRequest = HttpContext.Request;
            var parameters = Request.QueryString.Cast<string>()
                .Select(name => new { Name = name, Value = Request.QueryString[name] })
                .ToDictionary(p => p.Name, p => p.Value);

            parameters["Address"] = httpRequest.UserHostAddress;
            parameters["UserAgent"] = httpRequest.UserAgent;
          
            // Looking for AppPool Identity in order to assist with configuration.
            var appPoolIdentity = System.Security.Principal.WindowsIdentity.GetCurrent();
            parameters["UserID"] = appPoolIdentity != null ? appPoolIdentity.Name : "Unknown --your config needs fixing";

         var instance = Hub.Instance.GetInstance(id);
            var deployment = instance.CreateDeployment(parameters);
            if (!deployment.IsAllowed(HttpContext))
            {
                throw new HttpException(403, "Not Allowed");
            }
            deployment.Dry = dry;
            deployment.ExecuteAsync();
            return Request.IsAjaxRequest() ? (ActionResult)Json("OK") : Content("Successfully deployed");
        }

        // POST /deployment/smoketest/instance-name
        [AcceptVerbs("POST", "PUT")]
        public ActionResult SmokeTest(string id, string source = null)
        {
            var httpRequest = HttpContext.Request;
            var parameters = Request.QueryString.Cast<string>()
                .Select(name => new { Name = name, Value = Request.QueryString[name] })
                .ToDictionary(p => p.Name, p => p.Value);

            parameters["Address"] = httpRequest.UserHostAddress;
            parameters["UserAgent"] = httpRequest.UserAgent;

            // Looking for AppPool Identity in order to assist with configuration.
            var appPoolIdentity = System.Security.Principal.WindowsIdentity.GetCurrent();
            parameters["UserID"] = appPoolIdentity != null ? appPoolIdentity.Name : "Unknown --your config needs fixing";


         var instance = Hub.Instance.GetInstance(id);
            var smokeTest = instance.CreateSmokeTest(parameters);
            if (!smokeTest.IsAllowed(HttpContext))
            {
                throw new HttpException(403, "Not Allowed");
            }
            smokeTest.ExecuteAsync();
            return Request.IsAjaxRequest() ? (ActionResult)Json("OK") : Content("Successfully smoke tested");
        }
    }
}
