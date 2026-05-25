using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Text;
using System.Web.Script.Serialization;

namespace Eskd.AutoCAD
{
    internal sealed class ApiClient
    {
        private readonly JavaScriptSerializer _json = new JavaScriptSerializer();

        public ApiClient()
        {
            ServerUrl = "http://172.16.51.49:8010";
        }

        public string ServerUrl { get; set; }
        public string Token { get; private set; }
        public string Username { get; private set; }

        public bool IsAuthenticated
        {
            get { return !string.IsNullOrWhiteSpace(Token); }
        }

        public void Login(string serverUrl, string username, string password)
        {
            ServerUrl = TrimRightSlash(serverUrl);
            var body = "username=" + Uri.EscapeDataString(username) + "&password=" + Uri.EscapeDataString(password);
            var response = Request("POST", "/api/auth/token/", body, "application/x-www-form-urlencoded", false);
            Token = JsonMap.String(response, "token");
            Username = username;
        }

        public void Logout()
        {
            Token = null;
            Username = null;
        }

        public List<EskdProject> GetProjects()
        {
            var response = Request("GET", "/api/projects/", null, null, true);
            var result = new List<EskdProject>();
            foreach (var item in ResultItems(response))
            {
                result.Add(new EskdProject
                {
                    Id = JsonMap.Int(item, "id"),
                    ProjectId = JsonMap.String(item, "project_id"),
                    ProjectCode = JsonMap.String(item, "project_code"),
                    Name = JsonMap.String(item, "name")
                });
            }
            return result;
        }

        public EskdProject FindProject(string projectCode)
        {
            var response = Request("GET", "/api/projects/?project_code=" + Uri.EscapeDataString(projectCode), null, null, true);
            foreach (var item in ResultItems(response))
            {
                return new EskdProject
                {
                    Id = JsonMap.Int(item, "id"),
                    ProjectId = JsonMap.String(item, "project_id"),
                    ProjectCode = JsonMap.String(item, "project_code"),
                    Name = JsonMap.String(item, "name")
                };
            }
            return null;
        }

        public EskdProject SaveProject(string projectCode, string name)
        {
            var existing = FindProject(projectCode);
            if (existing != null)
            {
                return existing;
            }

            var payload = _json.Serialize(new Dictionary<string, object>
            {
                {"project_code", projectCode},
                {"name", name},
                {"is_active", true}
            });
            var response = Request("POST", "/api/projects/", payload, "application/json", true);
            return new EskdProject
            {
                Id = JsonMap.Int(response, "id"),
                ProjectId = JsonMap.String(response, "project_id"),
                ProjectCode = JsonMap.String(response, "project_code"),
                Name = JsonMap.String(response, "name")
            };
        }

        public List<EskdCabinet> GetCabinets(string projectId)
        {
            var response = Request("GET", "/api/cabinets/?project_id=" + Uri.EscapeDataString(projectId), null, null, true);
            var result = new List<EskdCabinet>();
            foreach (var item in ResultItems(response))
            {
                result.Add(ReadCabinet(item));
            }
            return result;
        }

        public EskdCabinet FindCabinet(string projectId, string cabinetCode)
        {
            var path = "/api/cabinets/?project_id=" + Uri.EscapeDataString(projectId)
                + "&cabinet_code=" + Uri.EscapeDataString(cabinetCode);
            var response = Request("GET", path, null, null, true);
            foreach (var item in ResultItems(response))
            {
                return ReadCabinet(item);
            }
            return null;
        }

        public EskdCabinet SaveCabinet(int projectDbId, string projectId, string cabinetCode, string name, string description)
        {
            var existing = FindCabinet(projectId, cabinetCode);
            if (existing != null)
            {
                return existing;
            }

            var payload = _json.Serialize(new Dictionary<string, object>
            {
                {"project", projectDbId},
                {"cabinet_code", cabinetCode},
                {"name", name ?? string.Empty},
                {"description", description ?? string.Empty}
            });
            var response = Request("POST", "/api/cabinets/", payload, "application/json", true);
            return ReadCabinet(response);
        }

        public EskdWireEndpoint CreateEndpoint(int cabinetDbId, string mark1, string mark2)
        {
            return CreateEndpoint(new EndpointCreateRequest
            {
                CabinetDbId = cabinetDbId,
                RefId = string.Empty,
                Mark1 = mark1,
                Mark2 = mark2,
                WireType = "-",
                WireColor = "-"
            });
        }

        public EskdWireEndpoint CreateEndpoint(EndpointCreateRequest request)
        {
            var payload = _json.Serialize(new Dictionary<string, object>
            {
                {"cabinet", request.CabinetDbId},
                {"ref_id", request.RefId ?? string.Empty},
                {"mark_1", string.IsNullOrWhiteSpace(request.Mark1) ? "-" : request.Mark1},
                {"mark_2", string.IsNullOrWhiteSpace(request.Mark2) ? "-" : request.Mark2},
                {"wire_type", string.IsNullOrWhiteSpace(request.WireType) ? "-" : request.WireType},
                {"wire_color", string.IsNullOrWhiteSpace(request.WireColor) ? "-" : request.WireColor},
                {"sync_status", "SYNCED"}
            });
            var response = Request("POST", "/api/wire-endpoints/", payload, "application/json", true);
            return new EskdWireEndpoint
            {
                EndpointId = JsonMap.String(response, "endpoint_id"),
                ProjectId = JsonMap.String(response, "project_id"),
                CabinetId = JsonMap.String(response, "cabinet_id"),
                RefId = JsonMap.String(response, "ref_id"),
                Mark1 = JsonMap.String(response, "mark_1"),
                Mark2 = JsonMap.String(response, "mark_2"),
                WireType = JsonMap.String(response, "wire_type"),
                WireColor = JsonMap.String(response, "wire_color"),
                SyncStatus = JsonMap.String(response, "sync_status")
            };
        }

        public List<WireDictionaryItem> GetWireTypes()
        {
            return GetWireDictionary("/api/wire-types/");
        }

        public List<WireDictionaryItem> GetWireColors()
        {
            return GetWireDictionary("/api/wire-colors/");
        }

        public void PatchEndpoint(
            string endpointId,
            string refId,
            string mark1,
            string mark2,
            string wireType,
            string wireColor,
            string syncStatus)
        {
            if (string.IsNullOrWhiteSpace(endpointId))
            {
                return;
            }

            var payload = new Dictionary<string, object>();
            if (refId != null)
            {
                payload["ref_id"] = refId;
            }
            if (mark1 != null)
            {
                payload["mark_1"] = mark1;
            }
            if (mark2 != null)
            {
                payload["mark_2"] = mark2;
            }
            if (wireType != null)
            {
                payload["wire_type"] = wireType;
            }
            if (wireColor != null)
            {
                payload["wire_color"] = wireColor;
            }
            if (syncStatus != null)
            {
                payload["sync_status"] = syncStatus;
            }

            Request(
                "PATCH",
                "/api/wire-endpoints/" + Uri.EscapeDataString(endpointId) + "/",
                _json.Serialize(payload),
                "application/json",
                true);
        }

        public DrawingCheckResult CheckDrawing(string cabinetId, List<string> endpointIds, List<string> emptyHandles)
        {
            var payload = _json.Serialize(new Dictionary<string, object>
            {
                {"cabinet_id", cabinetId},
                {"endpoint_ids", endpointIds},
                {"empty_endpoint_handles", emptyHandles}
            });
            var response = Request("POST", "/api/wire-endpoints/check-drawing/", payload, "application/json", true);
            var result = new DrawingCheckResult();
            object lines;
            if (response.TryGetValue("report_lines", out lines))
            {
                foreach (var line in (IEnumerable)lines)
                {
                    result.Lines.Add(Convert.ToString(line));
                }
            }
            return result;
        }

        private EskdCabinet ReadCabinet(IDictionary<string, object> item)
        {
            return new EskdCabinet
            {
                Id = JsonMap.Int(item, "id"),
                ProjectId = JsonMap.String(item, "project_id"),
                CabinetId = JsonMap.String(item, "cabinet_id"),
                CabinetCode = JsonMap.String(item, "cabinet_code"),
                Name = JsonMap.String(item, "name"),
                Description = JsonMap.String(item, "description")
            };
        }

        private List<WireDictionaryItem> GetWireDictionary(string path)
        {
            var response = Request("GET", path, null, null, true);
            var result = new List<WireDictionaryItem>();
            foreach (var item in ResultItems(response))
            {
                result.Add(new WireDictionaryItem
                {
                    Id = JsonMap.Int(item, "id"),
                    Name = JsonMap.String(item, "name")
                });
            }
            return result;
        }

        private IEnumerable<IDictionary<string, object>> ResultItems(IDictionary<string, object> response)
        {
            object raw;
            if (!response.TryGetValue("results", out raw))
            {
                yield return response;
                yield break;
            }

            foreach (var item in (IEnumerable)raw)
            {
                yield return (IDictionary<string, object>)item;
            }
        }

        private IDictionary<string, object> Request(string method, string path, string body, string contentType, bool authorized)
        {
            var request = (HttpWebRequest)WebRequest.Create(TrimRightSlash(ServerUrl) + path);
            request.Method = method;
            request.Accept = "application/json";
            request.Timeout = 30000;
            request.ReadWriteTimeout = 30000;

            if (authorized)
            {
                if (string.IsNullOrWhiteSpace(Token))
                {
                    throw new InvalidOperationException("Сначала выполните вход.");
                }
                request.Headers[HttpRequestHeader.Authorization] = "Token " + Token;
            }

            if (body != null)
            {
                var bytes = Encoding.UTF8.GetBytes(body);
                request.ContentType = contentType;
                request.ContentLength = bytes.Length;
                using (var stream = request.GetRequestStream())
                {
                    stream.Write(bytes, 0, bytes.Length);
                }
            }

            try
            {
                using (var response = (HttpWebResponse)request.GetResponse())
                using (var stream = response.GetResponseStream())
                using (var reader = new StreamReader(stream, Encoding.UTF8))
                {
                    return _json.Deserialize<Dictionary<string, object>>(reader.ReadToEnd());
                }
            }
            catch (WebException ex)
            {
                var message = ex.Message;
                if (ex.Response != null)
                {
                    using (var stream = ex.Response.GetResponseStream())
                    using (var reader = new StreamReader(stream, Encoding.UTF8))
                    {
                        message = reader.ReadToEnd();
                    }
                }
                throw new InvalidOperationException(message, ex);
            }
        }

        private static string TrimRightSlash(string value)
        {
            return string.IsNullOrWhiteSpace(value) ? value : value.TrimEnd('/');
        }
    }
}
