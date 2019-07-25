/*
* Copyright (c) {2018} torikulhabib (https://github.com/torikulhabib/com.github.torikulhabib.mindi)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: torikulhabib <torik.habib@Gmail.com>
*/

using Gtk;

namespace Mindi {
    public class CheckLink : Object {
        static CheckLink _instance = null;
        public static CheckLink instance {
            get {
                if (_instance == null)
                    _instance = new CheckLink ();
                return _instance;
            }
        }

        public string status;
        public bool is_running {get;set; default = false;}
        public signal void notif ();
        public signal void finished (bool finish);
        public signal void begin ();
        public string progress_msg;
        private Subprocess? subprocess;
        public CheckLink () {}

        construct {
        }

	    public async void check_link (string uri, bool other) {
	        begin ();
	    	string [] spawn_args;
            string [] spawn_env = Environ.get ();

            string cache_dir_path = Path.build_path (Path.DIR_SEPARATOR_S, Environment.get_user_cache_dir (), Environment.get_application_name());
                if (!other) {
		        spawn_args = {"youtube-dl", "--skip-download", "-o", "%(title)s.%(ext)s", uri};
		        } else {
		        spawn_args = {"youtube-dl", "-f", "251", "--skip-download", "-o", "%(title)s.%(ext)s", uri};
		        }
            try {
                    SubprocessLauncher launcher = new SubprocessLauncher (SubprocessFlags.STDERR_PIPE);
                    launcher.set_cwd (cache_dir_path);
                    launcher.set_environ (spawn_env);
                    subprocess = launcher.spawnv (spawn_args);
                    InputStream input_stream    = subprocess.get_stderr_pipe ();

                    convert_async.begin (input_stream, (obj, async_res) => {
                        try {
                            if (subprocess.wait_check ()) {
                                subprocess.get_successful ();
                                finished (true);
                            }
                        } catch (Error e) {
                                GLib.warning (e.message);
                        }
                    });
            } catch (Error e) {
                    GLib.warning (e.message);
            }
        }

        public async void cancel_now () {
            subprocess.force_exit ();
        }

        private async void convert_async (InputStream input_stream) {
            try {
                var charset_converter   = new CharsetConverter ("utf-8", "iso-8859-1");
                var costream            = new ConverterInputStream (input_stream, charset_converter);
                var data_input_stream   = new DataInputStream (costream);
                data_input_stream.set_newline_type (DataStreamNewlineType.ANY);

                int total = 0;

                while (true) {
                    string str_return = yield data_input_stream.read_line_utf8_async ();
                    if (str_return == null) {
                        break;
                    } else {
                        process_line (str_return, ref total);
                    }
                }
            } catch (Error e) {
                GLib.critical (e.message);
            }
        }

        private void process_line (string str_return, ref int total) {
            if (str_return.contains ("")) {
                if (str_return.has_prefix ("ERROR:") && str_return.index_of ("Unsupported URL") > -1) {
                    notif ();
                    status = ("Unsupported website");
                } else if (str_return.has_prefix ("ERROR:") && str_return.index_of ("requested format not available") > -1) {
                    notif ();
                    finished (false);
                    status = ("Download second format");
                } else if (str_return.has_prefix ("ERROR:") && str_return.index_of ("is not a valid URL.") > -1) {
                    notif ();
                    status = ("Not a valid URL");
                } else if (str_return.has_prefix ("ERROR:")) {
                    notif ();
                    progress_msg = str_return.substring (str_return.index_of (" "));
	                if (progress_msg.char_count () > 43) {
                        status = (progress_msg.substring (0, 42 - 0));
                    } else {
                        status = (progress_msg);
                    }
                }
            }
        }
    }
}
