package WebGUI::Help::MessageBoard;

our $HELP = {
	'message board add/edit' => {
		title => '61',
		body => '71',
		related => [
			{
				tag => 'message board template',
				namespace => 'MessageBoard'
			},
			{
				tag => 'wobjects using',
				namespace => 'Wobject'
			}
		]
	},
	'message board template' => {
		title => '73',
		body => '74',
		related => [
			{
				tag => 'wobject template',
				namespace => 'Wobject'
			}
		]
	}
};

1;
