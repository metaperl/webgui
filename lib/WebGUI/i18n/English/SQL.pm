package WebGUI::i18n::English::SQL;

our $I18N = {

    'sql title' => {
        message => q|SQL Macro|,
        lastUpdated => 1112466408,
    },

	'sql body' => {
		message => q|
<b>&#94;SQL();</b><br>
A one line SQL report. Sometimes you just need to pull something back from the database quickly. This macro is also useful in extending the SQL Report wobject. It uses the numeric macros (&#94;0; &#94;1; &#94;2; etc) to position data and can also use the &#94;&#94;rownum; macro just like the SQL Report wobject. Examples:<p>
 &#94;SQL("select count(*) from users","There are &#94;0; users on this system.");
<p>
&#94;SQL("select userId,username from users order by username","&lt;a href='&#94;/;?op=viewProfile&uid=&#94;0;'&gt;&#94;1;&lt;/a&gt;&lt;br&gt;");
<p>

|,
		lastUpdated => 1112466919,
	},
};

1;
