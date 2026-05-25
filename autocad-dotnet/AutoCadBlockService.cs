using System;
using System.Collections.Generic;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Geometry;

namespace Eskd.AutoCAD
{
    internal sealed class EndpointPatch
    {
        public string EndpointId { get; set; }
        public string RefId { get; set; }
        public string Mark1 { get; set; }
        public string Mark2 { get; set; }
        public string WireType { get; set; }
        public string WireColor { get; set; }
        public string SyncStatus { get; set; }
    }

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

        public List<EndpointPatch> AssignWireToSelectedBlocks(EskdProject project, EskdCabinet cabinet, string wireType, string wireColor)
        {
            var result = new List<EndpointPatch>();
            var document = Application.DocumentManager.MdiActiveDocument;
            var database = document.Database;
            var editor = document.Editor;

            var selection = editor.GetSelection(new SelectionFilter(new[] { new TypedValue(0, "INSERT") }));
            if (selection.Status != PromptStatus.OK)
            {
                throw new OperationCanceledException("Выбор блоков отменен.");
            }

            using (document.LockDocument())
            using (var transaction = database.TransactionManager.StartTransaction())
            {
                foreach (SelectedObject selected in selection.Value)
                {
                    if (selected == null)
                    {
                        continue;
                    }

                    var reference = transaction.GetObject(selected.ObjectId, OpenMode.ForRead) as BlockReference;
                    if (reference == null || !IsBlock(reference, transaction, MarkingBlockName))
                    {
                        continue;
                    }

                    var attributes = ReadAttributes(reference, transaction);
                    if (!IsCurrentContext(attributes, project, cabinet))
                    {
                        continue;
                    }

                    SetAttributes(reference, transaction, new Dictionary<string, string>
                    {
                        {"WIRE_TYPE", wireType},
                        {"WIRE_COLOR", wireColor},
                        {"SYNC_STATUS", "DIRTY"}
                    });

                    result.Add(new EndpointPatch
                    {
                        EndpointId = Attr(attributes, "ENDPOINT_ID"),
                        WireType = wireType,
                        WireColor = wireColor,
                        SyncStatus = "DIRTY"
                    });
                }

                transaction.Commit();
            }

            return result;
        }

        public List<EndpointPatch> LinkTwoMarkingBlocks(EskdProject project, EskdCabinet cabinet)
        {
            var result = new List<EndpointPatch>();
            var document = Application.DocumentManager.MdiActiveDocument;
            var database = document.Database;
            var editor = document.Editor;

            var firstId = PromptMarkingBlock(editor, "\nВыберите первую маркировку: ");
            var secondId = PromptMarkingBlock(editor, "\nВыберите пустую ответную маркировку: ");

            using (document.LockDocument())
            using (var transaction = database.TransactionManager.StartTransaction())
            {
                var first = (BlockReference)transaction.GetObject(firstId, OpenMode.ForRead);
                var second = (BlockReference)transaction.GetObject(secondId, OpenMode.ForRead);
                if (!IsBlock(first, transaction, MarkingBlockName) || !IsBlock(second, transaction, MarkingBlockName))
                {
                    throw new InvalidOperationException("Нужно выбрать блоки " + MarkingBlockName + ".");
                }
                var firstAttrs = ReadAttributes(first, transaction);
                var secondAttrs = ReadAttributes(second, transaction);

                if (!IsCurrentContext(firstAttrs, project, cabinet) || !IsCurrentContext(secondAttrs, project, cabinet))
                {
                    throw new InvalidOperationException("Обе маркировки должны относиться к выбранному проекту и шкафу.");
                }

                if (!IsEmptyMark(Attr(secondAttrs, "MARK_1")) || !IsEmptyMark(Attr(secondAttrs, "MARK_2")))
                {
                    throw new InvalidOperationException("Вторая маркировка должна быть пустой: MARK_1 и MARK_2 равны '-'.");
                }

                var mark1 = EmptyToDash(Attr(firstAttrs, "MARK_1"));
                var mark2 = EmptyToDash(Attr(firstAttrs, "MARK_2"));
                var refId = Attr(firstAttrs, "REF_ID");
                if (string.IsNullOrWhiteSpace(refId))
                {
                    refId = Attr(secondAttrs, "REF_ID");
                }
                if (string.IsNullOrWhiteSpace(refId))
                {
                    refId = Guid.NewGuid().ToString();
                }

                SetAttributes(first, transaction, new Dictionary<string, string>
                {
                    {"REF_ID", refId},
                    {"SYNC_STATUS", "DIRTY"}
                });
                SetAttributes(second, transaction, new Dictionary<string, string>
                {
                    {"REF_ID", refId},
                    {"MARK_1", mark2},
                    {"MARK_2", mark1},
                    {"SYNC_STATUS", "DIRTY"}
                });

                result.Add(new EndpointPatch
                {
                    EndpointId = Attr(firstAttrs, "ENDPOINT_ID"),
                    RefId = refId,
                    SyncStatus = "DIRTY"
                });
                result.Add(new EndpointPatch
                {
                    EndpointId = Attr(secondAttrs, "ENDPOINT_ID"),
                    RefId = refId,
                    Mark1 = mark2,
                    Mark2 = mark1,
                    SyncStatus = "DIRTY"
                });

                transaction.Commit();
            }

            return result;
        }

        public EndpointPatch ClearSelectedRef(EskdProject project, EskdCabinet cabinet)
        {
            var document = Application.DocumentManager.MdiActiveDocument;
            var database = document.Database;
            var editor = document.Editor;
            var objectId = PromptMarkingBlock(editor, "\nВыберите маркировку для очистки связи: ");

            using (document.LockDocument())
            using (var transaction = database.TransactionManager.StartTransaction())
            {
                var reference = (BlockReference)transaction.GetObject(objectId, OpenMode.ForRead);
                if (!IsBlock(reference, transaction, MarkingBlockName))
                {
                    throw new InvalidOperationException("Нужно выбрать блок " + MarkingBlockName + ".");
                }
                var attributes = ReadAttributes(reference, transaction);
                if (!IsCurrentContext(attributes, project, cabinet))
                {
                    throw new InvalidOperationException("Маркировка должна относиться к выбранному проекту и шкафу.");
                }

                SetAttributes(reference, transaction, new Dictionary<string, string>
                {
                    {"REF_ID", string.Empty},
                    {"SYNC_STATUS", "DIRTY"}
                });

                transaction.Commit();
                return new EndpointPatch
                {
                    EndpointId = Attr(attributes, "ENDPOINT_ID"),
                    RefId = string.Empty,
                    SyncStatus = "DIRTY"
                };
            }
        }

        private static bool IsBlock(BlockReference reference, Transaction transaction, string blockName)
        {
            var record = (BlockTableRecord)transaction.GetObject(reference.DynamicBlockTableRecord, OpenMode.ForRead);
            return string.Equals(record.Name, blockName, StringComparison.OrdinalIgnoreCase);
        }

        private static ObjectId PromptMarkingBlock(Editor editor, string message)
        {
            var options = new PromptEntityOptions(message);
            options.SetRejectMessage("\nНужно выбрать блок маркировки.");
            options.AddAllowedClass(typeof(BlockReference), true);

            var result = editor.GetEntity(options);
            if (result.Status != PromptStatus.OK)
            {
                throw new OperationCanceledException("Выбор блока отменен.");
            }

            return result.ObjectId;
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

        private static bool IsCurrentContext(Dictionary<string, string> attributes, EskdProject project, EskdCabinet cabinet)
        {
            return EqualsValue(attributes, "PROJECT_ID", project.ProjectId) &&
                EqualsValue(attributes, "CABINET_ID", cabinet.CabinetId);
        }

        private static string Attr(Dictionary<string, string> attributes, string key)
        {
            string value;
            return attributes.TryGetValue(key, out value) ? value : string.Empty;
        }

        private static bool IsEmptyMark(string value)
        {
            return string.IsNullOrWhiteSpace(value) || value == "-";
        }

        private static string EmptyToDash(string value)
        {
            return IsEmptyMark(value) ? "-" : value;
        }

        private static void SetAttributes(BlockReference reference, Transaction transaction, Dictionary<string, string> values)
        {
            reference.UpgradeOpen();
            foreach (ObjectId id in reference.AttributeCollection)
            {
                var attribute = transaction.GetObject(id, OpenMode.ForWrite) as AttributeReference;
                if (attribute == null)
                {
                    continue;
                }

                string value;
                if (values.TryGetValue(attribute.Tag.ToUpperInvariant(), out value))
                {
                    attribute.TextString = value ?? string.Empty;
                }
            }
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
