using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.Windows;

namespace Eskd.AutoCAD
{
    public sealed class Plugin : IExtensionApplication
    {
        private static PaletteSet _paletteSet;
        private static EskdPaletteControl _control;

        public void Initialize()
        {
        }

        public void Terminate()
        {
        }

        [CommandMethod("ESKD_PANEL")]
        public void ShowPanel()
        {
            if (_paletteSet == null)
            {
                _control = new EskdPaletteControl();
                _paletteSet = new PaletteSet("ESKD")
                {
                    Style = PaletteSetStyles.ShowAutoHideButton |
                            PaletteSetStyles.ShowCloseButton |
                            PaletteSetStyles.ShowPropertiesMenu,
                    MinimumSize = new System.Drawing.Size(420, 640)
                };
                _paletteSet.Add("ESKD", _control);
            }

            _paletteSet.Visible = true;
        }
    }
}
