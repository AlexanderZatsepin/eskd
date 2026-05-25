using System;
using System.Collections.Generic;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Geometry;

namespace Eskd.AutoCAD
{
    internal sealed class AutoCadBlockService
    {
        public const string MarkingBlockName = "Block_Test_Marking";

        public Point3d PromptMarkingInsertionPoint()
        {
            var document = Application.DocumentManager.MdiActiveDocument;
            var database = document.Database;
            var editor = document.Editor;

            using (document.LockDocument())
            using (var transaction = database.TransactionManager.StartTransaction())
            {
                var blockTable = (BlockTable)transaction.GetObject(database.BlockTableId, OpenMode.ForRead);
                if (!blockTable.Has(MarkingBlockName))
                {
                    throw new InvalidOperationException("В чертеже нет блока " + MarkingBlockName + ".");
                }

                var pointResult = editor.GetPoint("\nТочка вставки маркировки: ");
                if (pointResult.Status != PromptStatus.OK)
                {
                    throw new OperationCanceledException("Вставка отменена пользователем.");
                }

                transaction.Commit();
                return pointResult.Value;
            }
        }

        public void InsertMarkingBlock(EskdProject project, EskdCabinet cabinet, EskdWireEndpoint endpoint, Point3d point)
        {
            var document = Application.DocumentManager.MdiActiveDocument;
            var database = document.Database;

            using (document.LockDocument())
            using (var transaction = database.TransactionManager.StartTransaction())
            {
                var blockTable = (BlockTable)transaction.GetObject(database.BlockTableId, OpenMode.ForRead);
                if (!blockTable.Has(MarkingBlockName))
                {
                    throw new InvalidOperationException("В чертеже нет блока " + MarkingBlockName + ".");
                }

                var modelSpace = (BlockTableRecord)transaction.GetObject(blockTable[BlockTableRecord.ModelSpace], OpenMode.ForWrite);
                var definition = (BlockTableRecord)transaction.GetObject(blockTable[MarkingBlockName], OpenMode.ForRead);

                var reference = new BlockReference(point, definition.ObjectId);
                modelSpace.AppendEntity(reference);
                transaction.AddNewlyCreatedDBObject(reference, true);

                foreach (ObjectId id in definition)
                {
                    var attributeDefinition = transaction.GetObject(id, OpenMode.ForRead) as AttributeDefinition;
                    if (attributeDefinition == null || attributeDefinition.Constant)
                    {
                        continue;
                    }

                    var attribute = new AttributeReference();
                    attribute.SetAttributeFromBlock(attributeDefinition, reference.BlockTransform);
                    attribute.TextString = AttributeValue(attributeDefinition.Tag, project, cabinet, endpoint);
                    reference.AttributeCollection.AppendAttribute(attribute);
                    transaction.AddNewlyCreatedDBObject(attribute, true);
                }

                transaction.Commit();
            }
        }

        public DrawingEndpointSnapshot CollectMarkingEndpointIds(EskdProject project, EskdCabinet cabinet)
        {
            var snapshot = new DrawingEndpointSnapshot();
            var document = Application.DocumentManager.MdiActiveDocument;
            var database = document.Database;

            using (document.LockDocument())
            using (var transaction = database.TransactionManager.StartTransaction())
            {
                var blockTable = (BlockTable)transaction.GetObject(database.BlockTableId, OpenMode.ForRead);
                var modelSpace = (BlockTableRecord)transaction.GetObject(blockTable[BlockTableRecord.ModelSpace], OpenMode.ForRead);

                foreach (ObjectId id in modelSpace)
                {
                    var reference = transaction.GetObject(id, OpenMode.ForRead) as BlockReference;
                    if (reference == null || !IsBlock(reference, transaction, MarkingBlockName))
                    {
                        continue;
                    }

                    var attributes = ReadAttributes(reference, transaction);
                    if (!EqualsValue(attributes, "PROJECT_ID", project.ProjectId) ||
                        !EqualsValue(attributes, "CABINET_ID", cabinet.CabinetId))
                    {
                        continue;
                    }

                    string endpointId;
                    attributes.TryGetValue("ENDPOINT_ID", out endpointId);
                    if (string.IsNullOrWhiteSpace(endpointId))
                    {
                        snapshot.EmptyEndpointHandles.Add(reference.Handle.ToString());
                    }
                    else
                    {
                        snapshot.EndpointIds.Add(endpointId);
                    }
                }

                transaction.Commit();
            }

            return snapshot;
        }

        private static bool IsBlock(BlockReference reference, Transaction transaction, string blockName)
        {
            var record = (BlockTableRecord)transaction.GetObject(reference.DynamicBlockTableRecord, OpenMode.ForRead);
            return string.Equals(record.Name, blockName, StringComparison.OrdinalIgnoreCase);
        }

        private static Dictionary<string, string> ReadAttributes(BlockReference reference, Transaction transaction)
        {
            var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (ObjectId id in reference.AttributeCollection)
            {
                var attribute = transaction.GetObject(id, OpenMode.ForRead) as AttributeReference;
                if (attribute != null)
                {
                    result[attribute.Tag] = attribute.TextString;
                }
            }
            return result;
        }

        private static bool EqualsValue(Dictionary<string, string> attributes, string key, string expected)
        {
            string value;
            return attributes.TryGetValue(key, out value) &&
                string.Equals(value, expected, StringComparison.OrdinalIgnoreCase);
        }

        private static string AttributeValue(string tag, EskdProject project, EskdCabinet cabinet, EskdWireEndpoint endpoint)
        {
            switch ((tag ?? string.Empty).ToUpperInvariant())
            {
                case "ENDPOINT_ID": return endpoint.EndpointId;
                case "PROJECT_ID": return project.ProjectId;
                case "CABINET_ID": return cabinet.CabinetId;
                case "REF_ID": return endpoint.RefId ?? string.Empty;
                case "MARK_1": return endpoint.Mark1 ?? "-";
                case "MARK_2": return endpoint.Mark2 ?? "-";
                case "WIRE_TYPE": return string.IsNullOrWhiteSpace(endpoint.WireType) ? "-" : endpoint.WireType;
                case "WIRE_COLOR": return string.IsNullOrWhiteSpace(endpoint.WireColor) ? "-" : endpoint.WireColor;
                case "SYNC_STATUS": return string.IsNullOrWhiteSpace(endpoint.SyncStatus) ? "SYNCED" : endpoint.SyncStatus;
                default: return string.Empty;
            }
        }
    }

    internal sealed class DrawingEndpointSnapshot
    {
        public DrawingEndpointSnapshot()
        {
            EndpointIds = new List<string>();
            EmptyEndpointHandles = new List<string>();
        }

        public List<string> EndpointIds { get; private set; }
        public List<string> EmptyEndpointHandles { get; private set; }
    }
}
