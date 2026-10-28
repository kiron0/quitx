import os.path

app = defines["app"]
app_name = os.path.basename(app)

format = defines.get("format", "ULFO")
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = defines.get("icon")
background = defines["background"]

window_rect = ((200, 160), (640, 380))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
include_icon_view_settings = True
include_list_view_settings = False

arrange_by = None
label_pos = "bottom"
text_size = 13
icon_size = 128
icon_locations = {
    app_name: (170, 215),
    "Applications": (470, 215),
}
