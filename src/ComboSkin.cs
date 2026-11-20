// -*- mode: C# -*-
// Dark ComboBox chrome for the assembly desk (261120 master: the stock white popup made the
// light-gray item text unreadable). Hand-rolled FEFactory template like the tree item cells:
// dark body + dark popup list, accent border on hover/open, ComboBoxItem style for the rows.
using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Media;

namespace MaintOps;

public static class ComboSkin
{
    private static readonly Brush Panel  = MainWindow.Panel;
    private static readonly Brush Line   = MainWindow.Line;
    private static readonly Brush Fg     = MainWindow.Fg;
    private static readonly Brush FgDim  = MainWindow.FgDim;
    private static readonly Brush Accent = MainWindow.Accent;
    private static readonly Brush BtnBg  = MainWindow.BtnBg;
    private static readonly Brush PopBg  = MainWindow.F(Color.FromRgb(0x1A, 0x20, 0x27));

    private static Style? _combo, _item;
    private static ControlTemplate? _comboTpl, _toggleTpl;

    public static Style Combo => _combo ??= MakeCombo();
    public static Style Item  => _item  ??= MakeItem();

    private static Binding TP(string path, System.Windows.Data.BindingMode mode = System.Windows.Data.BindingMode.OneWay)
        => new(path) { RelativeSource = new RelativeSource(RelativeSourceMode.TemplatedParent), Mode = mode };

    private static ControlTemplate MakeComboTemplate()
    {
        if (_comboTpl != null) return _comboTpl;

        // ---- the little ▾ toggle face ----
        if (_toggleTpl == null)
        {
            var tb = new FrameworkElementFactory(typeof(DockPanel));
            var tbd = new FrameworkElementFactory(typeof(Border));
            tbd.SetValue(Border.BackgroundProperty, Brushes.Transparent);
            tbd.SetValue(Border.BorderBrushProperty, Line);
            tbd.SetValue(Border.BorderThicknessProperty, new Thickness(1, 0, 0, 0));
            var glyph = new FrameworkElementFactory(typeof(TextBlock));
            glyph.SetValue(TextBlock.TextProperty, "▾");
            glyph.SetValue(TextBlock.ForegroundProperty, FgDim);
            glyph.SetValue(TextBlock.FontSizeProperty, 10.0);
            glyph.SetValue(TextBlock.HorizontalAlignmentProperty, HorizontalAlignment.Center);
            glyph.SetValue(TextBlock.VerticalAlignmentProperty, VerticalAlignment.Center);
            tbd.AppendChild(glyph);
            tb.AppendChild(tbd);
            var tt = new ControlTemplate(typeof(ToggleButton)) { VisualTree = tb };
            var over = new Trigger { Property = ToggleButton.IsCheckedProperty, Value = true };
            over.Setters.Add(new Setter(Border.BackgroundProperty, BtnBg, "tbd"));
            tt.Triggers.Add(over);
            // name the border so the trigger can target it
            tbd.SetValue(FrameworkElement.NameProperty, "tbd");
            tt.RegisterName("tbd", tbd);
            _toggleTpl = tt;
        }

        // ---- outer combo face ----
        var root = new FrameworkElementFactory(typeof(Grid));
        var g1 = new FrameworkElementFactory(typeof(ColumnDefinition));
        g1.SetValue(ColumnDefinition.WidthProperty, new GridLength(1, GridUnitType.Star));
        var g2 = new FrameworkElementFactory(typeof(ColumnDefinition));
        g2.SetValue(ColumnDefinition.WidthProperty, GridLength.Auto);
        root.AppendChild(g1);
        root.AppendChild(g2);

        var bd = new FrameworkElementFactory(typeof(Border), "bd");
        bd.SetValue(FrameworkElement.NameProperty, "bd");
        bd.SetBinding(Border.BackgroundProperty, TP("Background"));
        bd.SetBinding(Border.BorderBrushProperty, TP("BorderBrush"));
        bd.SetValue(Border.BorderThicknessProperty, new Thickness(1));
        bd.SetValue(Border.CornerRadiusProperty, new CornerRadius(3));
        var cp = new FrameworkElementFactory(typeof(ContentPresenter));
        cp.SetBinding(ContentPresenter.ContentProperty, TP("SelectionBoxItem"));
        cp.SetBinding(ContentPresenter.ContentTemplateProperty, TP("SelectionBoxItemTemplate"));
        cp.SetValue(FrameworkElement.IsHitTestVisibleProperty, false);
        cp.SetValue(TextElement.ForegroundProperty, Fg);
        cp.SetValue(FrameworkElement.MarginProperty, new Thickness(5, 1, 2, 1));
        cp.SetValue(FrameworkElement.VerticalAlignmentProperty, VerticalAlignment.Center);
        bd.AppendChild(cp);
        cp.SetValue(Grid.ColumnProperty, 0);
        root.AppendChild(bd);

        var tgl = new FrameworkElementFactory(typeof(ToggleButton), "tgl");
        tgl.SetValue(FrameworkElement.NameProperty, "tgl");
        tgl.SetValue(Control.TemplateProperty, _toggleTpl);
        tgl.SetValue(FrameworkElement.WidthProperty, 20.0);
        tgl.SetValue(UIElement.FocusableProperty, false);
        tgl.SetValue(ButtonBase.ClickModeProperty, ClickMode.Press);
        tgl.SetValue(Control.BackgroundProperty, Brushes.Transparent);
        tgl.SetBinding(ToggleButton.IsCheckedProperty, TP("IsDropDownOpen", System.Windows.Data.BindingMode.TwoWay));
        tgl.SetValue(Grid.ColumnProperty, 1);
        root.AppendChild(tgl);

        // ---- dark popup ----
        var pop = new FrameworkElementFactory(typeof(Popup), "PART_Popup");
        pop.SetValue(FrameworkElement.NameProperty, "PART_Popup");
        pop.SetValue(Popup.PlacementProperty, PlacementMode.Bottom);
        pop.SetValue(Popup.StaysOpenProperty, false);
        pop.SetValue(Popup.AllowsTransparencyProperty, true);
        pop.SetBinding(Popup.PlacementTargetProperty, TP(""));
        pop.SetBinding(Popup.IsOpenProperty, TP("IsDropDownOpen", System.Windows.Data.BindingMode.TwoWay));
        var popBd = new FrameworkElementFactory(typeof(Border));
        popBd.SetValue(Border.BackgroundProperty, PopBg);
        popBd.SetValue(Border.BorderBrushProperty, Accent);
        popBd.SetValue(Border.BorderThicknessProperty, new Thickness(1));
        popBd.SetValue(Border.CornerRadiusProperty, new CornerRadius(3));
        popBd.SetValue(FrameworkElement.MinWidthProperty, 90.0);
        popBd.SetValue(TextElement.ForegroundProperty, Fg);
        var sv = new FrameworkElementFactory(typeof(ScrollViewer));
        sv.SetValue(ScrollViewer.MaxHeightProperty, 320.0);
        sv.SetValue(ScrollViewer.VerticalScrollBarVisibilityProperty, ScrollBarVisibility.Auto);
        var ip = new FrameworkElementFactory(typeof(ItemsPresenter));
        ip.SetValue(FrameworkElement.MarginProperty, new Thickness(2));
        sv.AppendChild(ip);
        popBd.AppendChild(sv);
        pop.AppendChild(popBd);
        root.AppendChild(pop);

        var tpl = new ControlTemplate(typeof(ComboBox)) { VisualTree = root };
        tpl.RegisterName("bd", bd);
        tpl.RegisterName("tgl", tgl);
        tpl.RegisterName("PART_Popup", pop);
        var hov = new Trigger { Property = UIElement.IsMouseOverProperty, Value = true };
        hov.Setters.Add(new Setter(Border.BorderBrushProperty, Accent, "bd"));
        tpl.Triggers.Add(hov);
        var open = new Trigger { Property = ComboBox.IsDropDownOpenProperty, Value = true };
        open.Setters.Add(new Setter(Border.BorderBrushProperty, Accent, "bd"));
        tpl.Triggers.Add(open);
        _comboTpl = tpl;
        return tpl;
    }

    private static Style MakeCombo()
    {
        var s = new Style(typeof(ComboBox));
        s.Setters.Add(new Setter(Control.BackgroundProperty, BtnBg));
        s.Setters.Add(new Setter(Control.ForegroundProperty, Fg));
        s.Setters.Add(new Setter(Control.BorderBrushProperty, Line));
        s.Setters.Add(new Setter(Control.FontSizeProperty, 11.5));
        s.Setters.Add(new Setter(Control.TemplateProperty, MakeComboTemplate()));
        return s;
    }

    private static Style MakeItem()
    {
        var s = new Style(typeof(ComboBoxItem));
        s.Setters.Add(new Setter(Control.BackgroundProperty, PopBg));
        s.Setters.Add(new Setter(Control.ForegroundProperty, Fg));
        s.Setters.Add(new Setter(FrameworkElement.MarginProperty, new Thickness(0)));
        s.Setters.Add(new Setter(Control.PaddingProperty, new Thickness(6, 3, 6, 3)));
        var t = new Trigger { Property = ComboBoxItem.IsHighlightedProperty, Value = true };
        t.Setters.Add(new Setter(Control.BackgroundProperty, BtnBg));
        t.Setters.Add(new Setter(Control.ForegroundProperty, Accent));
        s.Triggers.Add(t);
        return s;
    }
}
