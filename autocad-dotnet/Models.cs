using System;
using System.Collections.Generic;

namespace Eskd.AutoCAD
{
    internal sealed class EskdProject
    {
        public int Id { get; set; }
        public string ProjectId { get; set; }
        public string ProjectCode { get; set; }
        public string Name { get; set; }

        public override string ToString()
        {
            return string.IsNullOrWhiteSpace(Name) ? ProjectCode : ProjectCode + " - " + Name;
        }
    }

    internal sealed class EskdCabinet
    {
        public int Id { get; set; }
        public string ProjectId { get; set; }
        public string CabinetId { get; set; }
        public string CabinetCode { get; set; }
        public string Name { get; set; }
        public string Description { get; set; }

        public override string ToString()
        {
            return string.IsNullOrWhiteSpace(Name) ? CabinetCode : CabinetCode + " - " + Name;
        }
    }

    internal sealed class EskdWireEndpoint
    {
        public string EndpointId { get; set; }
        public string ProjectId { get; set; }
        public string CabinetId { get; set; }
        public string RefId { get; set; }
        public string Mark1 { get; set; }
        public string Mark2 { get; set; }
        public string WireType { get; set; }
        public string WireColor { get; set; }
        public string SyncStatus { get; set; }
    }

    internal sealed class DrawingCheckResult
    {
        public DrawingCheckResult()
        {
            Lines = new List<string>();
        }

        public List<string> Lines { get; private set; }
    }

    internal static class JsonMap
    {
        public static string String(IDictionary<string, object> map, string key)
        {
            object value;
            if (!map.TryGetValue(key, out value) || value == null)
            {
                return string.Empty;
            }
            return Convert.ToString(value);
        }

        public static int Int(IDictionary<string, object> map, string key)
        {
            object value;
            if (!map.TryGetValue(key, out value) || value == null)
            {
                return 0;
            }
            return Convert.ToInt32(value);
        }
    }
}
