using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;
using AcadApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace Eskd.AutoCAD
{
    internal sealed class EskdPaletteControl : UserControl
    {
        private readonly ApiClient _api = new ApiClient();
        private readonly AutoCadBlockService _blocks = new AutoCadBlockService();

        private TextBox _serverUrl;
        private TextBox _username;
        private TextBox _password;
        private Panel _authIndicator;
        private Label _authStatus;

        private ComboBox _projects;
        private TextBox _projectCode;
        private TextBox _projectName;
        private TextBox _projectId;

        private ComboBox _cabinets;
        private TextBox _cabinetCode;
        private TextBox _cabinetName;
        private TextBox _cabinetDescription;
        private TextBox _cabinetId;

        private TextBox _mark1;
        private TextBox _mark2;
        private ComboBox _wireTypes;
        private ComboBox _wireColors;
        private ListBox _checkResult;

        private EskdProject _selectedProject;
        private EskdCabinet _selectedCabinet;

        public EskdPaletteControl()
        {
            BuildLayout();
            UpdateAuthStatus();
        }

        private void BuildLayout()
        {
            Dock = DockStyle.Fill;
            AutoScroll = true;

            var root = new TableLayoutPanel
            {
                Dock = DockStyle.Top,
                AutoSize = true,
                ColumnCount = 1,
                Padding = new Padding(8)
            };
            Controls.Add(root);

            root.Controls.Add(AuthGroup());
            root.Controls.Add(ProjectGroup());
            root.Controls.Add(CabinetGroup());
            root.Controls.Add(MarkingGroup());
            root.Controls.Add(CheckGroup());
        }

        private Control AuthGroup()
        {
            var group = Group("Авторизация");
            _serverUrl = TextBox(_api.ServerUrl);
            _username = TextBox("admin");
            _password = TextBox("");
            _password.UseSystemPasswordChar = true;

            group.Controls.Add(Row(Label("Сервер"), _serverUrl));
            group.Controls.Add(Row(Label("Логин"), _username));
            group.Controls.Add(Row(Label("Пароль"), _password));

            var buttons = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true };
            buttons.Controls.Add(Button("Войти", OnLogin));
            buttons.Controls.Add(Button("Выйти", (s, e) => { _api.Logout(); UpdateAuthStatus(); }));
            group.Controls.Add(buttons);

            var status = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, Padding = new Padding(0, 4, 0, 0) };
            _authIndicator = new Panel { Width = 16, Height = 16, BackColor = Color.Firebrick, Margin = new Padding(3, 5, 6, 3) };
            _authStatus = new Label { AutoSize = true, Text = "Вход не выполнен", Padding = new Padding(0, 4, 0, 0) };
            status.Controls.Add(_authIndicator);
            status.Controls.Add(_authStatus);
            group.Controls.Add(status);

            return group;
        }

        private Control ProjectGroup()
        {
            var group = Group("Проект");
            _projectId = ReadOnlyTextBox();
            _projects = Combo();
            _projectCode = TextBox("");
            _projectName = TextBox("");

            group.Controls.Add(Row(Label("UUID"), _projectId));
            group.Controls.Add(Row(Label("Список"), _projects));
            group.Controls.Add(Row(Label("Шифр"), _projectCode));
            group.Controls.Add(Row(Label("Название"), _projectName));

            var buttons = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true };
            buttons.Controls.Add(Button("Загрузить", OnLoadProjects));
            buttons.Controls.Add(Button("Выбрать", OnSelectProject));
            buttons.Controls.Add(Button("Сохранить", OnSaveProject));
            group.Controls.Add(buttons);

            return group;
        }

        private Control CabinetGroup()
        {
            var group = Group("Шкаф");
            _cabinetId = ReadOnlyTextBox();
            _cabinets = Combo();
            _cabinetCode = TextBox("");
            _cabinetName = TextBox("");
            _cabinetDescription = TextBox("");

            group.Controls.Add(Row(Label("UUID"), _cabinetId));
            group.Controls.Add(Row(Label("Список"), _cabinets));
            group.Controls.Add(Row(Label("Код"), _cabinetCode));
            group.Controls.Add(Row(Label("Название"), _cabinetName));
            group.Controls.Add(Row(Label("Описание"), _cabinetDescription));

            var buttons = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true };
            buttons.Controls.Add(Button("Загрузить", OnLoadCabinets));
            buttons.Controls.Add(Button("Выбрать", OnSelectCabinet));
            buttons.Controls.Add(Button("Сохранить", OnSaveCabinet));
            group.Controls.Add(buttons);

            return group;
        }

        private Control MarkingGroup()
        {
            var group = Group("Маркировка");
            var content = new TableLayoutPanel
            {
                Dock = DockStyle.Top,
                AutoSize = true,
                ColumnCount = 1
            };
            group.Controls.Add(content);

            _mark1 = TextBox("-");
            _mark2 = TextBox("-");
            _wireTypes = Combo();
            _wireColors = Combo();

            var dictionaryButtons = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true };
            dictionaryButtons.Controls.Add(Button("Загрузить справочники", OnLoadWireDictionaries));
            dictionaryButtons.Controls.Add(Button("Назначить выбранным", OnAssignWireTypeColor));

            var linkButtons = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true };
            linkButtons.Controls.Add(Button("Связать", OnLinkMarkings));
            linkButtons.Controls.Add(Button("Очистить связь", OnClearRef));
            linkButtons.Controls.Add(Button("Очистить связи выбранным", OnClearSelectedRefs));

            var copyButtons = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true };
            copyButtons.Controls.Add(Button("Копировать маркировки", OnCopyMarkings));
            copyButtons.Controls.Add(Button("Переоформить ID выбранным", OnReissueSelectedIds));
            copyButtons.Controls.Add(Button("Перенести в выбранный шкаф", OnMoveSelectedToCabinet));

            var editButtons = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true };
            editButtons.Controls.Add(Button("Обновить БД из выбранных", OnSyncSelectedBlocksToDb));
            editButtons.Controls.Add(Button("Очистить маркировку", OnClearSelectedMarks));
            editButtons.Controls.Add(Button("Удалить маркировку", OnDeleteSelectedMarkings));

            var createButtons = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true };
            createButtons.Controls.Add(Button("Добавить блок маркировки", OnInsertMarking));
            createButtons.Controls.Add(Button("Редактировать выбранную маркировку", OnEditMarking));

            content.Controls.Add(Row(Label("MARK_1"), _mark1));
            content.Controls.Add(Row(Label("MARK_2"), _mark2));
            content.Controls.Add(createButtons);
            content.Controls.Add(editButtons);
            content.Controls.Add(copyButtons);
            content.Controls.Add(linkButtons);
            content.Controls.Add(Row(Label("Тип"), _wireTypes));
            content.Controls.Add(Row(Label("Цвет"), _wireColors));
            content.Controls.Add(dictionaryButtons);
            return group;
        }

        private Control CheckGroup()
        {
            var group = Group("Сверка");
            var content = new TableLayoutPanel
            {
                Dock = DockStyle.Top,
                AutoSize = true,
                ColumnCount = 1
            };
            group.Controls.Add(content);
            content.Controls.Add(Button("Сверить чертеж с БД", OnCheckDrawing));
            _checkResult = new ListBox { Dock = DockStyle.Top, Height = 180 };
            content.Controls.Add(_checkResult);
            return group;
        }

        private void OnLogin(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                _api.Login(_serverUrl.Text, _username.Text, _password.Text);
                UpdateAuthStatus();
            });
        }

        private void OnLoadProjects(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                _projects.DataSource = _api.GetProjects();
            });
        }

        private void OnSelectProject(object sender, EventArgs eventArgs)
        {
            var project = _projects.SelectedItem as EskdProject;
            if (project == null)
            {
                return;
            }
            SetProject(project);
            _cabinets.DataSource = null;
        }

        private void OnSaveProject(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                var project = _api.SaveProject(_projectCode.Text.Trim(), _projectName.Text.Trim());
                SetProject(project);
                OnLoadProjects(sender, eventArgs);
            });
        }

        private void OnLoadCabinets(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                RequireProject();
                _cabinets.DataSource = _api.GetCabinets(_selectedProject.ProjectId);
            });
        }

        private void OnSelectCabinet(object sender, EventArgs eventArgs)
        {
            var cabinet = _cabinets.SelectedItem as EskdCabinet;
            if (cabinet == null)
            {
                return;
            }
            SetCabinet(cabinet);
        }

        private void OnSaveCabinet(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                RequireProject();
                var cabinet = _api.SaveCabinet(
                    _selectedProject.Id,
                    _selectedProject.ProjectId,
                    _cabinetCode.Text.Trim(),
                    _cabinetName.Text.Trim(),
                    _cabinetDescription.Text.Trim());
                SetCabinet(cabinet);
                OnLoadCabinets(sender, eventArgs);
            });
        }

        private void OnInsertMarking(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                RequireProject();
                RequireCabinet();
                var insertionPoint = _blocks.PromptMarkingInsertionPoint();
                var endpoint = _api.CreateEndpoint(_selectedCabinet.Id, _mark1.Text.Trim(), _mark2.Text.Trim());
                endpoint.ProjectId = _selectedProject.ProjectId;
                endpoint.CabinetId = _selectedCabinet.CabinetId;
                _blocks.InsertMarkingBlock(_selectedProject, _selectedCabinet, endpoint, insertionPoint);
            });
        }

        private void OnEditMarking(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                RequireProject();
                RequireCabinet();
                var block = _blocks.PromptMarkingForEdit(_selectedProject, _selectedCabinet);
                using (var form = new MarkingEditForm(block.Mark1, block.Mark2))
                {
                    if (form.ShowDialog(this) != DialogResult.OK)
                    {
                        return;
                    }

                    var patch = _blocks.UpdateMarkingMarks(block.ObjectId, form.Mark1, form.Mark2);
                    PatchEndpoint(patch);
                    _mark1.Text = patch.Mark1;
                    _mark2.Text = patch.Mark2;
                    MessageBox.Show("Маркировка обновлена.", "ESKD", MessageBoxButtons.OK, MessageBoxIcon.Information);
                }
            });
        }

        private void OnLoadWireDictionaries(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                _wireTypes.DataSource = _api.GetWireTypes();
                _wireColors.DataSource = _api.GetWireColors();
            });
        }

        private void OnAssignWireTypeColor(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                RequireProject();
                RequireCabinet();
                var wireType = SelectedDictionaryName(_wireTypes);
                var wireColor = SelectedDictionaryName(_wireColors);
                var patches = _blocks.AssignWireToSelectedBlocks(_selectedProject, _selectedCabinet, wireType, wireColor);
                PatchEndpoints(patches);
                MessageBox.Show("Назначено блоков: " + patches.Count, "ESKD", MessageBoxButtons.OK, MessageBoxIcon.Information);
            });
        }

        private void OnLinkMarkings(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                RequireProject();
                RequireCabinet();
                var patches = _blocks.LinkTwoMarkingBlocks(_selectedProject, _selectedCabinet);
                PatchEndpoints(patches);
                MessageBox.Show("Маркировки связаны.", "ESKD", MessageBoxButtons.OK, MessageBoxIcon.Information);
            });
        }

        private void OnClearRef(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                RequireProject();
                RequireCabinet();
                var patch = _blocks.ClearSelectedRef(_selectedProject, _selectedCabinet);
                PatchEndpoint(patch);
                MessageBox.Show("Связь очищена.", "ESKD", MessageBoxButtons.OK, MessageBoxIcon.Information);
            });
        }

        private void OnClearSelectedRefs(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                RequireProject();
                RequireCabinet();
                var patches = _blocks.ClearRefsInSelectedBlocks(_selectedProject, _selectedCabinet);
                PatchEndpoints(patches);
                MessageBox.Show("Очищено связей: " + patches.Count, "ESKD", MessageBoxButtons.OK, MessageBoxIcon.Information);
            });
        }

        private void OnClearSelectedMarks(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                RequireProject();
                RequireCabinet();
                var patches = _blocks.ClearMarksInSelectedBlocks(_selectedProject, _selectedCabinet);
                PatchEndpoints(patches);
                _mark1.Text = "-";
                _mark2.Text = "-";
                MessageBox.Show("Очищено маркировок: " + patches.Count, "ESKD", MessageBoxButtons.OK, MessageBoxIcon.Information);
            });
        }

        private void OnSyncSelectedBlocksToDb(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                RequireProject();
                RequireCabinet();
                var patches = _blocks.ReadSelectedBlocksForDbSync(_selectedProject, _selectedCabinet);
                PatchEndpoints(patches);
                MessageBox.Show("Обновлено записей в БД: " + patches.Count, "ESKD", MessageBoxButtons.OK, MessageBoxIcon.Information);
            });
        }

        private void OnDeleteSelectedMarkings(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                RequireProject();
                RequireCabinet();
                if (MessageBox.Show(
                    "Удалить выбранные маркировки из чертежа и БД?",
                    "ESKD",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Warning) != DialogResult.Yes)
                {
                    return;
                }

                var endpointIds = _blocks.DeleteSelectedMarkings(_selectedProject, _selectedCabinet);
                foreach (var endpointId in endpointIds)
                {
                    _api.DeleteEndpoint(endpointId);
                }
                MessageBox.Show("Удалено маркировок: " + endpointIds.Count, "ESKD", MessageBoxButtons.OK, MessageBoxIcon.Information);
            });
        }

        private void OnCopyMarkings(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                RequireProject();
                RequireCabinet();
                var result = _blocks.CopySelectedMarkingsWithNewIds(
                    _selectedProject,
                    _selectedCabinet,
                    _selectedCabinet.Id,
                    _api.CreateEndpoint);
                MessageBox.Show("Скопировано маркировок: " + result.Count, "ESKD", MessageBoxButtons.OK, MessageBoxIcon.Information);
            });
        }

        private void OnReissueSelectedIds(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                RequireProject();
                RequireCabinet();
                var result = _blocks.ReissueSelectedIds(
                    _selectedProject,
                    _selectedCabinet,
                    _selectedCabinet.Id,
                    _api.CreateEndpoint);
                MessageBox.Show("Переоформлено маркировок: " + result.Count, "ESKD", MessageBoxButtons.OK, MessageBoxIcon.Information);
            });
        }

        private void OnMoveSelectedToCabinet(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                RequireProject();
                RequireCabinet();
                var patches = _blocks.MoveSelectedToCabinet(_selectedProject, _selectedCabinet);
                foreach (var patch in patches)
                {
                    _api.MoveEndpointToCabinet(patch.EndpointId, _selectedCabinet.Id, patch.RefId);
                }
                MessageBox.Show("Перенесено маркировок: " + patches.Count, "ESKD", MessageBoxButtons.OK, MessageBoxIcon.Information);
            });
        }

        private void OnCheckDrawing(object sender, EventArgs eventArgs)
        {
            RunUi(() =>
            {
                RequireProject();
                RequireCabinet();
                var snapshot = _blocks.CollectMarkingEndpointIds(_selectedProject, _selectedCabinet);
                var result = _api.CheckDrawing(_selectedCabinet.CabinetId, snapshot.EndpointIds, snapshot.EmptyEndpointHandles);
                _checkResult.Items.Clear();
                foreach (var line in result.Lines)
                {
                    _checkResult.Items.Add(line);
                }
            });
        }

        private void SetProject(EskdProject project)
        {
            _selectedProject = project;
            _projectId.Text = project.ProjectId;
            _projectCode.Text = project.ProjectCode;
            _projectName.Text = project.Name;
            _selectedCabinet = null;
            _cabinetId.Text = "";
            _cabinetCode.Text = "";
            _cabinetName.Text = "";
            _cabinetDescription.Text = "";
        }

        private void SetCabinet(EskdCabinet cabinet)
        {
            _selectedCabinet = cabinet;
            _cabinetId.Text = cabinet.CabinetId;
            _cabinetCode.Text = cabinet.CabinetCode;
            _cabinetName.Text = cabinet.Name;
            _cabinetDescription.Text = cabinet.Description;
        }

        private void PatchEndpoints(IEnumerable<EndpointPatch> patches)
        {
            foreach (var patch in patches)
            {
                PatchEndpoint(patch);
            }
        }

        private void PatchEndpoint(EndpointPatch patch)
        {
            if (patch == null || string.IsNullOrWhiteSpace(patch.EndpointId))
            {
                return;
            }

            _api.PatchEndpoint(
                patch.EndpointId,
                patch.RefId,
                patch.Mark1,
                patch.Mark2,
                patch.WireType,
                patch.WireColor,
                patch.SyncStatus);
        }

        private static string SelectedDictionaryName(ComboBox comboBox)
        {
            var item = comboBox.SelectedItem as WireDictionaryItem;
            if (item == null || string.IsNullOrWhiteSpace(item.Name))
            {
                return "-";
            }
            return item.Name;
        }

        private void UpdateAuthStatus()
        {
            _authIndicator.BackColor = _api.IsAuthenticated ? Color.ForestGreen : Color.Firebrick;
            _authStatus.Text = _api.IsAuthenticated ? "Вход выполнен: " + _api.Username : "Вход не выполнен";
        }

        private void RequireProject()
        {
            if (_selectedProject == null)
            {
                throw new InvalidOperationException("Сначала выберите или сохраните проект.");
            }
        }

        private void RequireCabinet()
        {
            if (_selectedCabinet == null)
            {
                throw new InvalidOperationException("Сначала выберите или сохраните шкаф.");
            }
        }

        private void RunUi(Action action)
        {
            try
            {
                action();
            }
            catch (OperationCanceledException ex)
            {
                MessageBox.Show(ex.Message, "ESKD", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "ESKD", MessageBoxButtons.OK, MessageBoxIcon.Error);
                var document = AcadApp.DocumentManager.MdiActiveDocument;
                if (document != null)
                {
                    document.Editor.WriteMessage("\nESKD: " + ex.Message);
                }
            }
        }

        private static GroupBox Group(string title)
        {
            return new GroupBox
            {
                Text = title,
                Dock = DockStyle.Top,
                AutoSize = true,
                Padding = new Padding(8),
                Margin = new Padding(0, 0, 0, 8)
            };
        }

        private static Control Row(Control label, Control editor)
        {
            var row = new TableLayoutPanel
            {
                Dock = DockStyle.Top,
                AutoSize = true,
                ColumnCount = 2
            };
            row.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 90));
            row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            row.Controls.Add(label, 0, 0);
            row.Controls.Add(editor, 1, 0);
            return row;
        }

        private static Label Label(string text)
        {
            return new Label { Text = text, Dock = DockStyle.Fill, AutoSize = true, Padding = new Padding(0, 5, 4, 0) };
        }

        private static TextBox TextBox(string text)
        {
            return new TextBox { Text = text, Dock = DockStyle.Fill };
        }

        private static TextBox ReadOnlyTextBox()
        {
            return new TextBox { ReadOnly = true, Dock = DockStyle.Fill };
        }

        private static ComboBox Combo()
        {
            return new ComboBox { Dock = DockStyle.Fill, DropDownStyle = ComboBoxStyle.DropDownList };
        }

        private static Button Button(string text, EventHandler handler)
        {
            var button = new Button { Text = text, AutoSize = true, Margin = new Padding(3) };
            button.Click += handler;
            return button;
        }
    }

    internal sealed class MarkingEditForm : Form
    {
        private readonly TextBox _mark1;
        private readonly TextBox _mark2;

        public MarkingEditForm(string mark1, string mark2)
        {
            Text = "Редактировать маркировку";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            StartPosition = FormStartPosition.CenterParent;
            MinimizeBox = false;
            MaximizeBox = false;
            Width = 360;
            Height = 170;

            var root = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 2,
                RowCount = 3,
                Padding = new Padding(10)
            };
            root.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 70));
            root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            Controls.Add(root);

            _mark1 = new TextBox { Text = string.IsNullOrWhiteSpace(mark1) ? "-" : mark1, Dock = DockStyle.Fill };
            _mark2 = new TextBox { Text = string.IsNullOrWhiteSpace(mark2) ? "-" : mark2, Dock = DockStyle.Fill };
            root.Controls.Add(new Label { Text = "MARK_1", AutoSize = true, Padding = new Padding(0, 5, 0, 0) }, 0, 0);
            root.Controls.Add(_mark1, 1, 0);
            root.Controls.Add(new Label { Text = "MARK_2", AutoSize = true, Padding = new Padding(0, 5, 0, 0) }, 0, 1);
            root.Controls.Add(_mark2, 1, 1);

            var buttons = new FlowLayoutPanel
            {
                Dock = DockStyle.Fill,
                FlowDirection = FlowDirection.RightToLeft
            };
            var ok = new Button { Text = "Сохранить", DialogResult = DialogResult.OK, AutoSize = true };
            var cancel = new Button { Text = "Отмена", DialogResult = DialogResult.Cancel, AutoSize = true };
            buttons.Controls.Add(ok);
            buttons.Controls.Add(cancel);
            root.SetColumnSpan(buttons, 2);
            root.Controls.Add(buttons, 0, 2);

            AcceptButton = ok;
            CancelButton = cancel;
        }

        public string Mark1
        {
            get { return Normalize(_mark1.Text); }
        }

        public string Mark2
        {
            get { return Normalize(_mark2.Text); }
        }

        private static string Normalize(string value)
        {
            return string.IsNullOrWhiteSpace(value) ? "-" : value.Trim();
        }
    }
}
