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

    internal sealed class MarkingCopyResult
    {
        public int Count { get; set; }
    }

    internal sealed class MoveCabinetPatch
    {
        public string EndpointId { get; set; }
        public string RefId { get; set; }
    }

    internal sealed class EditableMarkingBlock
    {
        public ObjectId ObjectId { get; set; }
        public string EndpointId { get; set; }
        public string Mark1 { get; set; }
        public string Mark2 { get; set; }
    }

    internal sealed class OriginalMarkingBlock
    {
        public ObjectId ObjectId { get; set; }
        public Dictionary<string, string> Attributes { get; set; }
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

                var modelSpace = (BlockTableRecord)transaction.GetObject(blockTable[BlockTableRecord.ModelSpace], OpenMode.ForRead);
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
                var modelSpace = (BlockTableRecord)transaction.GetObject(blockTable[BlockTableRecord.ModelSpace], OpenMode.ForWrite);

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
                foreach (ObjectId selectedId in selection.Value.GetObjectIds())
                {
                    var reference = transaction.GetObject(selectedId, OpenMode.ForRead) as BlockReference;
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

        public EditableMarkingBlock PromptMarkingForEdit(EskdProject project, EskdCabinet cabinet)
        {
            var document = Application.DocumentManager.MdiActiveDocument;
            var database = document.Database;
            var editor = document.Editor;
            var objectId = PromptMarkingBlock(editor, "\nВыберите маркировку для редактирования: ");

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

                var endpointId = Attr(attributes, "ENDPOINT_ID");
                if (string.IsNullOrWhiteSpace(endpointId))
                {
                    throw new InvalidOperationException("У выбранной маркировки пустой ENDPOINT_ID.");
                }

                transaction.Commit();
                return new EditableMarkingBlock
                {
                    ObjectId = objectId,
                    EndpointId = endpointId,
                    Mark1 = EmptyToDash(Attr(attributes, "MARK_1")),
                    Mark2 = EmptyToDash(Attr(attributes, "MARK_2"))
                };
            }
        }

        public EndpointPatch UpdateMarkingMarks(ObjectId objectId, string mark1, string mark2)
        {
            var document = Application.DocumentManager.MdiActiveDocument;
            var database = document.Database;

            using (document.LockDocument())
            using (var transaction = database.TransactionManager.StartTransaction())
            {
                var reference = (BlockReference)transaction.GetObject(objectId, OpenMode.ForRead);
                if (!IsBlock(reference, transaction, MarkingBlockName))
                {
                    throw new InvalidOperationException("Нужно выбрать блок " + MarkingBlockName + ".");
                }

                var attributes = ReadAttributes(reference, transaction);
                var endpointId = Attr(attributes, "ENDPOINT_ID");
                if (string.IsNullOrWhiteSpace(endpointId))
                {
                    throw new InvalidOperationException("У выбранной маркировки пустой ENDPOINT_ID.");
                }

                var normalizedMark1 = EmptyToDash(mark1);
                var normalizedMark2 = EmptyToDash(mark2);
                SetAttributes(reference, transaction, new Dictionary<string, string>
                {
                    {"MARK_1", normalizedMark1},
                    {"MARK_2", normalizedMark2},
                    {"SYNC_STATUS", "DIRTY"}
                });

                transaction.Commit();
                return new EndpointPatch
                {
                    EndpointId = endpointId,
                    Mark1 = normalizedMark1,
                    Mark2 = normalizedMark2,
                    SyncStatus = "DIRTY"
                };
            }
        }

        public MarkingCopyResult CopySelectedMarkingsWithNewIds(
            EskdProject project,
            EskdCabinet cabinet,
            int cabinetDbId,
            Func<EndpointCreateRequest, EskdWireEndpoint> createEndpoint)
        {
            var document = Application.DocumentManager.MdiActiveDocument;
            var database = document.Database;
            var editor = document.Editor;

            var selection = editor.GetSelection(new SelectionFilter(new[] { new TypedValue(0, "INSERT") }));
            if (selection.Status != PromptStatus.OK)
            {
                throw new OperationCanceledException("Выбор блоков отменен.");
            }

            var basePointResult = editor.GetPoint("\nБазовая точка копирования: ");
            if (basePointResult.Status != PromptStatus.OK)
            {
                throw new OperationCanceledException("Копирование отменено.");
            }

            var targetOptions = new PromptPointOptions("\nНовая точка вставки: ");
            targetOptions.BasePoint = basePointResult.Value;
            targetOptions.UseBasePoint = true;
            var targetPointResult = editor.GetPoint(targetOptions);
            if (targetPointResult.Status != PromptStatus.OK)
            {
                throw new OperationCanceledException("Копирование отменено.");
            }

            using (document.LockDocument())
            using (var transaction = database.TransactionManager.StartTransaction())
            {
                var originals = SelectedContextMarkings(selection.Value, transaction, project, cabinet);
                if (originals.Count == 0)
                {
                    throw new InvalidOperationException("В выборе нет маркировок выбранного проекта и шкафа.");
                }

                var refMap = NewRefMap(originals);
                var ids = new ObjectIdCollection();
                foreach (var original in originals)
                {
                    ids.Add(original.ObjectId);
                }

                var blockTable = (BlockTable)transaction.GetObject(database.BlockTableId, OpenMode.ForRead);
                var modelSpace = (BlockTableRecord)transaction.GetObject(blockTable[BlockTableRecord.ModelSpace], OpenMode.ForWrite);
                var idMap = new IdMapping();
                database.DeepCloneObjects(ids, modelSpace.ObjectId, idMap, false);
                var cloneIds = CloneIdMap(idMap);
                var displacement = Matrix3d.Displacement(targetPointResult.Value - basePointResult.Value);

                foreach (var original in originals)
                {
                    ObjectId cloneId;
                    if (!cloneIds.TryGetValue(original.ObjectId, out cloneId))
                    {
                        continue;
                    }

                    var oldRefId = Attr(original.Attributes, "REF_ID");
                    var newRefId = refMap.ContainsKey(oldRefId) ? refMap[oldRefId] : string.Empty;
                    var endpoint = createEndpoint(new EndpointCreateRequest
                    {
                        CabinetDbId = cabinetDbId,
                        RefId = newRefId,
                        Mark1 = Attr(original.Attributes, "MARK_1"),
                        Mark2 = Attr(original.Attributes, "MARK_2"),
                        WireType = Attr(original.Attributes, "WIRE_TYPE"),
                        WireColor = Attr(original.Attributes, "WIRE_COLOR")
                    });

                    var clone = (BlockReference)transaction.GetObject(cloneId, OpenMode.ForWrite);
                    clone.TransformBy(displacement);
                    SetAttributes(clone, transaction, new Dictionary<string, string>
                    {
                        {"ENDPOINT_ID", endpoint.EndpointId},
                        {"PROJECT_ID", project.ProjectId},
                        {"CABINET_ID", cabinet.CabinetId},
                        {"REF_ID", endpoint.RefId ?? string.Empty},
                        {"MARK_1", endpoint.Mark1 ?? "-"},
                        {"MARK_2", endpoint.Mark2 ?? "-"},
                        {"WIRE_TYPE", string.IsNullOrWhiteSpace(endpoint.WireType) ? "-" : endpoint.WireType},
                        {"WIRE_COLOR", string.IsNullOrWhiteSpace(endpoint.WireColor) ? "-" : endpoint.WireColor},
                        {"SYNC_STATUS", "SYNCED"}
                    });
                }

                transaction.Commit();
                return new MarkingCopyResult { Count = originals.Count };
            }
        }

        public MarkingCopyResult ReissueSelectedIds(
            EskdProject project,
            EskdCabinet cabinet,
            int cabinetDbId,
            Func<EndpointCreateRequest, EskdWireEndpoint> createEndpoint)
        {
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
                var originals = SelectedContextMarkings(selection.Value, transaction, project, cabinet);
                if (originals.Count == 0)
                {
                    throw new InvalidOperationException("В выборе нет маркировок выбранного проекта и шкафа.");
                }

                var refMap = NewRefMap(originals);
                foreach (var original in originals)
                {
                    var oldRefId = Attr(original.Attributes, "REF_ID");
                    var newRefId = refMap.ContainsKey(oldRefId) ? refMap[oldRefId] : string.Empty;
                    var endpoint = createEndpoint(new EndpointCreateRequest
                    {
                        CabinetDbId = cabinetDbId,
                        RefId = newRefId,
                        Mark1 = Attr(original.Attributes, "MARK_1"),
                        Mark2 = Attr(original.Attributes, "MARK_2"),
                        WireType = Attr(original.Attributes, "WIRE_TYPE"),
                        WireColor = Attr(original.Attributes, "WIRE_COLOR")
                    });

                    var reference = (BlockReference)transaction.GetObject(original.ObjectId, OpenMode.ForRead);
                    SetAttributes(reference, transaction, new Dictionary<string, string>
                    {
                        {"ENDPOINT_ID", endpoint.EndpointId},
                        {"REF_ID", endpoint.RefId ?? string.Empty},
                        {"SYNC_STATUS", "SYNCED"}
                    });
                }

                transaction.Commit();
                return new MarkingCopyResult { Count = originals.Count };
            }
        }

        public List<MoveCabinetPatch> MoveSelectedToCabinet(EskdProject targetProject, EskdCabinet targetCabinet)
        {
            var result = new List<MoveCabinetPatch>();
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
                var markings = SelectedMarkings(selection.Value, transaction);
                if (markings.Count == 0)
                {
                    throw new InvalidOperationException("В выборе нет блоков маркировки.");
                }

                var preservedRefs = PreservedRefSet(markings);
                foreach (var marking in markings)
                {
                    var endpointId = Attr(marking.Attributes, "ENDPOINT_ID");
                    if (string.IsNullOrWhiteSpace(endpointId))
                    {
                        continue;
                    }

                    var oldRefId = Attr(marking.Attributes, "REF_ID");
                    var newRefId = preservedRefs.ContainsKey(oldRefId) ? oldRefId : string.Empty;
                    var reference = (BlockReference)transaction.GetObject(marking.ObjectId, OpenMode.ForRead);
                    SetAttributes(reference, transaction, new Dictionary<string, string>
                    {
                        {"PROJECT_ID", targetProject.ProjectId},
                        {"CABINET_ID", targetCabinet.CabinetId},
                        {"REF_ID", newRefId},
                        {"SYNC_STATUS", "DIRTY"}
                    });
                    result.Add(new MoveCabinetPatch
                    {
                        EndpointId = endpointId,
                        RefId = newRefId
                    });
                }

                transaction.Commit();
            }

            return result;
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

        private static List<OriginalMarkingBlock> SelectedContextMarkings(
            SelectionSet selection,
            Transaction transaction,
            EskdProject project,
            EskdCabinet cabinet)
        {
            var all = SelectedMarkings(selection, transaction);
            var result = new List<OriginalMarkingBlock>();
            foreach (var marking in all)
            {
                if (IsCurrentContext(marking.Attributes, project, cabinet))
                {
                    result.Add(marking);
                }
            }
            return result;
        }

        private static List<OriginalMarkingBlock> SelectedMarkings(SelectionSet selection, Transaction transaction)
        {
            var result = new List<OriginalMarkingBlock>();
            foreach (ObjectId selectedId in selection.GetObjectIds())
            {
                var reference = transaction.GetObject(selectedId, OpenMode.ForRead) as BlockReference;
                if (reference == null || !IsBlock(reference, transaction, MarkingBlockName))
                {
                    continue;
                }

                result.Add(new OriginalMarkingBlock
                {
                    ObjectId = selectedId,
                    Attributes = ReadAttributes(reference, transaction)
                });
            }
            return result;
        }

        private static Dictionary<string, string> NewRefMap(List<OriginalMarkingBlock> originals)
        {
            var counts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            foreach (var original in originals)
            {
                var refId = Attr(original.Attributes, "REF_ID");
                if (string.IsNullOrWhiteSpace(refId))
                {
                    continue;
                }

                counts[refId] = counts.ContainsKey(refId) ? counts[refId] + 1 : 1;
            }

            var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var pair in counts)
            {
                if (pair.Value > 1)
                {
                    result[pair.Key] = Guid.NewGuid().ToString();
                }
            }
            return result;
        }

        private static Dictionary<string, bool> PreservedRefSet(List<OriginalMarkingBlock> originals)
        {
            var counts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            foreach (var original in originals)
            {
                var refId = Attr(original.Attributes, "REF_ID");
                if (string.IsNullOrWhiteSpace(refId))
                {
                    continue;
                }

                counts[refId] = counts.ContainsKey(refId) ? counts[refId] + 1 : 1;
            }

            var result = new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase);
            foreach (var pair in counts)
            {
                if (pair.Value > 1)
                {
                    result[pair.Key] = true;
                }
            }
            return result;
        }

        private static Dictionary<ObjectId, ObjectId> CloneIdMap(IdMapping idMap)
        {
            var result = new Dictionary<ObjectId, ObjectId>();
            foreach (IdPair pair in idMap)
            {
                if (pair.IsCloned)
                {
                    result[pair.Key] = pair.Value;
                }
            }
            return result;
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
            if (!reference.IsWriteEnabled)
            {
                reference.UpgradeOpen();
            }
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
