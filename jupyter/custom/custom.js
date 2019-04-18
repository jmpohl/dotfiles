// prevents jupyter from auto closing your brackets
IPython.CodeCell.options_default.cm_config.autoCloseBrackets = false;


// type q to return to jupyter mode
require([
	'base/js/namespace',
	'codemirror/keymap/vim',
	'nbextensions/vim_binding/vim_binding'
], function(ns) {
	CodeMirror.Vim.defineEx("quit", "q", function(cm){
		ns.notebook.command_mode();
		ns.notebook.focus_cell();
	});
});

// Easier Movement in vim
require([
  'nbextensions/vim_binding/vim_binding',   // depends your installation
], function() {
  // Swap j/k and gj/gk (Note that <Plug> mappings)
  CodeMirror.Vim.map("J", "}", "normal");
  CodeMirror.Vim.map("K", "{", "normal");
  CodeMirror.Vim.map("L", "$", "normal");
  CodeMirror.Vim.map("H", "0", "normal");
  CodeMirror.Vim.map("J", "}", "visual");
  CodeMirror.Vim.map("K", "{", "visual");
  CodeMirror.Vim.map("H", "0", "visual");
  CodeMirror.Vim.map("L", "$", "visual");
});

// Add Cell Below
Jupyter.keyboard_manager.actions.register({
    'handler': function(env, event) {
        env.notebook.command_mode();
        var actions = Jupyter.keyboard_manager.actions;
        actions.call('jupyter-notebook:insert-cell-below', event, env);
        env.notebook.edit_mode();
    }
}, 'insert-below-jp', 'vim-binding');

require([
  'nbextensions/vim_binding/vim_binding',
  'base/js/namespace',
], function(vim_binding, ns) {
  // Add post callback
  vim_binding.on_ready_callbacks.push(function(){
    var km = ns.keyboard_manager;
    // Indicate the key combination to run the commans
    km.edit_shortcuts.add_shortcut('ctrl-b', 'vim-binding:insert-below-jp', true);
  });
});
