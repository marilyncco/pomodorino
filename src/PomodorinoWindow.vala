/*
    Todo list application drawing inspiration from the pomodoro technique
    Copyright (C) 2014 Thomas Chace

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

using Gtk; // For the GUI.
using Gee; // For fancy and useful things like HashSet.
using Granite.Widgets;
using GLib;

public class Pomodorino : Window {
    // Main Window

    int pos = 0;
    private AddTask dialog; // We need a dialog to add new tasks.
    private Timer timer;
    private TreeIter iter; // Treeview iter
    private ListStore store; // See above.
    private TreeView tree;
    private TaskStore backend;
    private string current; // The currently selected task.
    
    enum Column {
        TASK,
        DATE,
        PRIORITY,
    }
    
    public Pomodorino (string[] args) {
        this.current = "::";
        destroy.connect(quit); // Close button = app exit.
        //Gtk.Settings.get_default().set("gtk-application-prefer-dark-theme", true);
        this.backend = new TaskStore(); // Backend for saving/loading files.
        this.dialog = new AddTask(); // Makes a dialog window for adding tasks.
        this.dialog.title = "Add Task"; // Set the title here for localisation.
        this.dialog.set_transient_for(this); // Makes it a modal dialog.
        this.dialog.response.connect(addtask_response); // Set the dialog's button to respond with our addtask method.
        
        this.window_position = WindowPosition.CENTER; // Center the window on the screen.
        set_default_size(425, 450);

        try {
            // Load the window icon.
            this.icon = new Gdk.Pixbuf.from_file("/opt/pomodorino/images/logo.png");
        } catch (Error e) {
            // If it can't find the logo, the app exits and reports an error.
            stdout.printf("Error: %s\n", e.message);
        }
        
        build_ui(); // Builds the user interface.
        load(); // Load tasks.
    }

    void on_changed (Gtk.TreeSelection selection) {
        // Makes sure we know what's currently selected in the Treeview.
        Gtk.TreeModel model;
        Gtk.TreeIter iter;
        string task;
        string date;
        string priority;

        if (selection.get_selected (out model, out iter)) {
            model.get (iter,
                            Column.TASK, out task,
                            Column.DATE, out date,
                            Column.PRIORITY, out priority);
            this.current = task + ":" + date + ":" + priority;
        }
    }

    private void save() {
        // Saves the tasks before quitting the app.
        var tasks = new ArrayList<string>();
        Gtk.TreeModelForeachFunc add_to_tasks = (model, path, iter) => {
            GLib.Value name;
            GLib.Value date;
            GLib.Value priority;

            this.store.get_value(iter, 0, out date);
            this.store.get_value(iter, 1, out name);
            this.store.get_value(iter, 2, out priority);
            tasks.add((string) name + ":" + (string) date + ":" + (string) priority);
            return false;
        };
        this.store.foreach(add_to_tasks);
        backend.tasks = tasks;
        backend.save();
    }
    
    private void quit() {
        save();
        Gtk.main_quit();
    }
    
    private void load() {
        // Loads tasks from DConf.
        backend.load();
        var saved_tasks = backend.tasks;
        foreach (string i in saved_tasks) {
            new_task(i);
        }
    }
    
    private void new_task(string task) {
        string[] task_data = task.split(":");
        
        var name = task_data[0];
        var date = task_data[1];
        var priority = task_data[2];
        // Adds a new task to the main window and to the backend.
        this.store.append(out this.iter);
        this.store.set(this.iter, 0, date, 1, name, 2, priority);
    }
    
    private void remove_task() {
        // Deletes a task from the Treeview and the configuration.
        this.backend.remove(this.current);
        stdout.printf(this.current);
        this.store.clear();
        var saved_tasks = backend.tasks;
        foreach (string i in saved_tasks) {
            new_task(i);
        }
    }
    
    private void addtask_response(Dialog source, int response_id) {
        // Sets up the signals for the AddTask() dialog.
        switch(response_id) {
            case ResponseType.ACCEPT:
                string text = this.dialog.entry.text;
                new_task(text);
                this.backend.add(text);
                this.dialog.hide(); // Saves it for later use.
                this.dialog.entry.set_text("");
                break;
            case ResponseType.CLOSE:
                this.dialog.hide(); // Saves it for later use.
                break;
        }
    }
    
    private void start_timer() {
        save();
        if (this.current in this.backend.tasks) {
            timer = new Timer();
            timer.destroy.connect(() => {
               // if (response_id == ResponseType.CANCEL || response_id == ResponseType.DELETE_EVENT || response_id == ResponseType.CLOSE) {
                this.show_all();
                timer.running = false;
                timer.destroy();
                //}
            });
            this.hide();
            
            // Starts a timer for the current task.
            timer.task = this.current;
            timer.show_all();
            timer.start();
        } else {
            // If the current task isn't in the backend yet (AKA: It's been deleted), prompt the user.
            Gtk.MessageDialog msg = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.OK, "Please select a task to start.");
            msg.response.connect ((response_id) => {
            switch (response_id) {
                case Gtk.ResponseType.OK:
                    msg.destroy();
                    break;
                case Gtk.ResponseType.DELETE_EVENT:
                    msg.destroy();
                    break;
            }
            });
            msg.show();
        }
    }

    private void build_indicator() {
        var indicator = new AppIndicator.Indicator("Pomodorino", "/opt/pomodorino/images/logo.png",
                                      AppIndicator.IndicatorCategory.APPLICATION_STATUS);

        indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE);

        var menu = new Gtk.Menu();

        // Add Timer Button
        var timer_item = new Gtk.MenuItem.with_label("Start Timer");
        timer_item.activate.connect(() => {
            indicator.set_status(AppIndicator.IndicatorStatus.ATTENTION);
            start_timer();
        });
        timer_item.show();
        menu.append(timer_item);

        var show_item = new Gtk.MenuItem.with_label("Hide");
        show_item.show();
        show_item.activate.connect(() => {
            if (this.visible) {
                show_item.label = "Show";
                this.hide();
            } else {
                this.show_all();
                show_item.label = "Hide";
            }

        });
        menu.append(show_item);

        // Add Quit button
        var item = new Gtk.MenuItem.with_label("Quit");
        item.show();
        item.activate.connect(() => {
            quit();
        });
        menu.append(item);

        indicator.set_menu(menu);
    }
    
    private void build_ui() {
        build_indicator();
        // Starts out by setting up the HeaderBar and buttons.
        //var toolbar = new Toolbar();
        //toolbar.orientation = Gtk.Orientation.HORIZONTAL;
        //toolbar.get_style_context().add_class(STYLE_CLASS_PRIMARY_TOOLBAR);
        this.title = "Pomodorino - Tasks";
        var toolbar = new HeaderBar();
        toolbar.show_close_button = true; // Makes sure the user has a close button available.
        this.set_titlebar(toolbar);
        toolbar.title = "Tasks";
        toolbar.subtitle = "Pomodorino";

        // Add a task.
        Image new_img = new Image.from_icon_name ("document-new", Gtk.IconSize.SMALL_TOOLBAR);
        ToolButton new_button = new ToolButton (new_img, null);
        toolbar.add(new_button);
        new_button.clicked.connect(this.dialog.show_all);
        
        // Delete a task.
        Image delete_img = new Image.from_icon_name ("edit-delete", Gtk.IconSize.SMALL_TOOLBAR);
        var delete_button = new ToolButton(delete_img, null);
        var delete_style = delete_button.get_style_context ();
        delete_style.add_class("destructive-action");
        toolbar.add(delete_button);
        delete_button.clicked.connect(remove_task);

        var separator = new Gtk.SeparatorToolItem();
        //var separator = new Separator(Gtk.Orientation.HORIZONTAL);
        
        separator.draw = true;
        separator.expand = true;
        //toolbar.pack_end(separator);

        // Start a task.
        Image start_img = new Image.from_icon_name("media-playback-start", IconSize.SMALL_TOOLBAR);
        var start_button = new ToolButton(start_img, null);
        toolbar.pack_end(start_button);
        start_button.clicked.connect(start_timer);

        toolbar.pack_end(separator);

        // Menu button
        var menu = new Gtk.Menu();
        Gtk.MenuItem about = new Gtk.MenuItem.with_label("About");
	    menu.add(about);
	    Granite.Widgets.AboutDialog about_dialog = new AboutPomodorino();
	    //Gtk.AboutDialog about_dialog = new AboutPomodorino();
        try {
            about_dialog.logo = new Gdk.Pixbuf.from_file("/opt/pomodorino/images/logo.png");
        } catch (Error e) {
            stdout.printf("Error: %s", e.message);
        }
	    about_dialog.hide();
	    about.activate.connect (() => {
		      about_dialog.show();
		});
        var menu_button = new AppMenu(menu);
        toolbar.pack_end(menu_button);
        
        // Then we get the TreeView set up.
        this.tree = new TreeView();
        this.tree.set_rules_hint(true);
        this.tree.reorderable = true;
        this.store = new ListStore(3, typeof(string), typeof(string), typeof(string));
        this.tree.set_model(this.store);

        // Inserts our columns.
        this.tree.insert_column(get_column("Date"), -1);
        this.tree.insert_column(get_column("Name"), -1);
        this.tree.insert_column(get_column("Priority"), -1);

        // Scrolling is nice.
        var scroll = new ScrolledWindow (null, null);
        scroll.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
        scroll.add(this.tree);

        // Time to put everything together.
        var vbox = new Box (Orientation.VERTICAL, 0);
        vbox.pack_start(toolbar, false, true, 0);
        vbox.pack_start(scroll, true, true, 0);
        add(vbox);

        // Makes sure we know when the selection changes.
        var selection = this.tree.get_selection();
        selection.changed.connect(this.on_changed);
    }
    
    TreeViewColumn get_column (string title) {
        // This pain in the ass lets us add text to TreeView entries.
        var col = new TreeViewColumn();
        col.title = title;
        col.sort_column_id = this.pos;

        var crt = new CellRendererText();
        col.pack_start(crt, false);
        col.add_attribute(crt, "text", this.pos++);

        return col;
    }
}

void main (string[] args) {
    // Let's start up Gtk.
    Gtk.init(ref args);

    // Then let's start the main window.
    var window = new Pomodorino(args); 
    window.show_all();

    Gtk.main();
}
