//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
pub const FormatterOptions = struct {
    html_options: HtmlFormatterOptions,

    pub fn init() FormatterOptions {
        // TODO load from local file
        return FormatterOptions{ .html_options = HtmlFormatterOptions.init() };
    }
};

pub const HtmlFormatterOptions = struct {
    tab_width: usize,
    auto_self_close: bool,

    pub fn init() HtmlFormatterOptions {
        return HtmlFormatterOptions{ .tab_width = 4, .auto_self_close = true };
    }
};
