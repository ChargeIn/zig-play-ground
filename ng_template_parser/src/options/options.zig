//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
pub const FormatterOptions = struct {
    tab_width: usize,
    auto_self_close: bool,

    pub fn init() FormatterOptions {
        // TODO load from local file
        return FormatterOptions{ .tab_width = 4, .auto_self_close = true };
    }
};
