insert into webguiVersion values ('6.2.5','upgrade',unix_timestamp());

update template set template='^JavaScript(\"<tmpl_var session.config.extrasURL>/textFix.js\");\r\n<tmpl_if htmlArea3.supported> \r\n\r\n^RawHeadTags(\r\n	<script type=\'text/javascript\'> \r\n	 _editor_url = \'<tmpl_var session.config.extrasURL>/htmlArea3/\'; \r\n	 _editor_lang = \'en\'; \r\n	</script>\r\n\r\n	<script type=\'text/javascript\' src=\'<tmpl_var session.config.extrasURL>/htmlArea3/htmlarea.js\'> \r\n	</script>\r\n\r\n	<script language=\'JavaScript\'> \r\n	 HTMLArea.loadPlugin(\'TableOperations\'); \r\n	</script>\r\n);\r\n\r\n<script language=\"JavaScript\"> \r\nfunction initEditor() { \r\n  editor = new HTMLArea(\"<tmpl_var form.name>\"); \r\n  editor.registerPlugin(TableOperations); \r\n\r\n  setTimeout(function() { \r\n   editor.generate(); \r\n   }, 500); \r\n  return false; \r\n} \r\nwindow.setTimeout(\"initEditor()\", 250); \r\n</script> \r\n\r\n</tmpl_if> \r\n\r\n<tmpl_var textarea> ' where templateId=6 and namespace='richEditor';

update page set parentId='0' where parentId is null;
update page set parentId='0' where parentId='';
