//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
pub const FormatterOptions = struct {
    tab_width: usize,

    pub fn init() FormatterOptions {
        // TODO load from local file
        return FormatterOptions{ .tab_width = 4 };
    }
};
