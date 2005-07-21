package WebGUI::Auth;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2005 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use CGI::Util qw(rearrange);
use DBI;
use strict qw(subs vars);
use Tie::IxHash;
use WebGUI::DateTime;
use WebGUI::ErrorHandler;
use WebGUI::FormProcessor;
use WebGUI::HTML;
use WebGUI::HTMLForm;
use WebGUI::HTTP;
use WebGUI::Icon;
use WebGUI::International;
use WebGUI::Macro;
use WebGUI::Session;
use WebGUI::SQL;
use WebGUI::TabForm;
use WebGUI::Asset::Template;
use WebGUI::URL;
use WebGUI::Utility;
use WebGUI::Operation::Shared;
use WebGUI::Operation::Profile;


=head1 NAME

Package WebGUI::Auth

=head1 DESCRIPTION

An abstract class for all authentication modules to extend.

=head1 SYNOPSIS

 use WebGUI::Auth;
 our @ISA = qw(WebGUI::Auth);

=head1 METHODS

These methods are available from this class:

=cut

#-------------------------------------------------------------------
sub _isDuplicateUsername {
	my $self = shift;
	my $username = shift;
	#Return false if the user is already logged in, but not changing their username.
	return 0 if($self->userId ne "1" && $session{user}{username} eq $username);
	my ($otherUser) = WebGUI::SQL->quickArray("select count(*) from users where username=".quote($username));
	return 0 if !$otherUser;
	$self->error('<li>'.WebGUI::International::get(77).' "'.$username.'too", "'.$username.'2", '.'"'.$username.'_'.WebGUI::DateTime::epochToHuman(time(),"%y").'"');
	return 1;
}

#-------------------------------------------------------------------

=head2 _isValidUsername ( username )

Validates the username passed in.

=cut

sub _isValidUsername {
   my $self = shift;
   my $username = shift;
   my $error = "";
   
   return 1 if($self->userId ne "1" && $session{user}{username} eq $username);
   
   if ($username =~ /^\s/ || $username =~ /\s$/) {
      $error .= '<li>'.WebGUI::International::get(724);
   }
   if ($username eq "") {
      $error .= '<li>'.WebGUI::International::get(725);
   }
   unless ($username =~ /^[A-Za-z0-9\-\_\.\,\@]+$/) {
   	  $error .= '<li>'.WebGUI::International::get(747);
   }
   $self->error($error);
   return $error eq "";
}

#-------------------------------------------------------------------
sub _logLogin {
   WebGUI::SQL->write("insert into userLoginLog values (".quote($_[0]).",".quote($_[1]).",".time().","
	.quote($session{env}{REMOTE_ADDR}).",".quote($session{env}{HTTP_USER_AGENT}).")");
}

#-------------------------------------------------------------------

=head2 addUserForm ( userId )

Creates elements for the add user form specific to this Authentication Method.

=cut

sub addUserForm {
   #Added for interface purposes only.  Needs to be implemented in the subclass.
}

#-------------------------------------------------------------------

=head2 addUserFormSave ( properties [,userId] )

Saves user elements unique to this authentication method

=cut

sub addUserFormSave {
   my $self = shift;
   $self->saveParams(($_[1] || $self->userId),$self->authMethod,$_[0]);
}

#-------------------------------------------------------------------

=head2 authenticate ( )

Superclass method that performs standard login routines.  This method should return true or false.

=cut

sub authenticate {
   my $self = shift;
   my $username = shift;
   my $user = WebGUI::SQL->quickHashRef("select userId,authMethod,status from users where username=".quote($username));
   my $uid = $user->{userId};
   #If userId does not exist or is not active, fail login
   if(!$uid){
      $self->error(WebGUI::International::get(68));
	  return 0;
   } elsif($user->{status} ne 'Active'){
      $self->error(WebGUI::International::get(820));
	  _logLogin($uid, "failure");
	  return 0;
   }
   
   #Set User Id
   $self->user(WebGUI::User->new($uid));
   return 1;
}

#-------------------------------------------------------------------

=head2 authMethod ( [authMethod] )

Gets or sets the authMethod in the Auth Object

=head3 authMethod

   A string which sets the auth method for an instance of this class

=cut

sub authMethod {
   my $self = shift;
   return $self->{authMethod} if(!$_[0]);
   $self->{authMethod} = $_[0];
}

#-------------------------------------------------------------------

=head2 createAccount ( method [,vars] )

Superclass method that performs general functionality for creating new accounts.

=head3 method

Auth method that the form for creating users should call
   
=head3 vars
   
Array ref of template vars from subclass
   
=cut

sub createAccount {
    my $self = shift;
	my $method = $_[0];
	my $vars = $_[1];
	$vars->{title} = WebGUI::International::get(54);
   	
	$vars->{'create.form.header'} = WebGUI::Form::formHeader({});
	$vars->{'create.form.header'} .= WebGUI::Form::hidden({"name"=>"op","value"=>"auth"});
    $vars->{'create.form.header'} .= WebGUI::Form::hidden({"name"=>"method","value"=>$method});
	
	#User Defined Options
    $vars->{'create.form.profile'} = WebGUI::Operation::Profile::getRequiredProfileFields();
	
	$vars->{'create.form.submit'} = WebGUI::Form::submit({});
    $vars->{'create.form.footer'} = WebGUI::Form::formFooter();
	
    $vars->{'login.url'} = WebGUI::URL::page('op=auth&method=init');
    $vars->{'login.label'} = WebGUI::International::get(58);

	return WebGUI::Asset::Template->new($self->getCreateAccountTemplateId)->process($vars);
}

#-------------------------------------------------------------------

=head2 createAccountSave ( username,properties [,password,profile] )

Superclass method that performs general functionality for saving new accounts.

=head3 username

Username for the account being created
   
=head3 properties
   
Properties from the subclass that should be saved as authentication parameters
   
=head3 password

Password entered by the user.  This is only used in for sending the user a notification by email of his/her username/password

=head3 profile
   
Hashref of profile values returned by the function WebGUI::Operation::Profile::validateProfileData()
   
=cut

sub createAccountSave {
   my $self = shift;
   my $username = $_[0];
   my $properties = $_[1];
   my $password = $_[2];
   my $profile = $_[3];
   
      
   my $u = WebGUI::User->new("new");
   $self->user($u);
   my $userId = $u->userId;
   $u->username($username);
   $u->authMethod($self->authMethod);
   $u->karma($session{setting}{karmaPerLogin},"Login","Just for logging in.") if ($session{setting}{useKarma});
   WebGUI::Operation::Profile::saveProfileFields($u,$profile) if($profile);
   $self->saveParams($userId,$self->authMethod,$properties);
   
   if ($self->getSetting("sendWelcomeMessage")){
      my $authInfo = "\n\n".WebGUI::International::get(50).": ".$username;
      $authInfo .= "\n".WebGUI::International::get(51).": ".$password if($password);
      $authInfo .= "\n\n";
      WebGUI::MessageLog::addEntry($self->userId,"",WebGUI::International::get(870),$self->getSetting("welcomeMessage").$authInfo);
   }
   
   WebGUI::Session::convertVisitorToUser($session{var}{sessionId},$userId);
   _logLogin($userId,"success");
   system(WebGUI::Macro::process($session{setting}{runOnRegistration})) if ($session{setting}{runOnRegistration} ne "");
   WebGUI::MessageLog::addInternationalizedEntry('',$session{setting}{onNewUserAlertGroup},'',536) if ($session{setting}{alertOnNewUser});
   return "";
}

#-------------------------------------------------------------------

=head2 deactivateAccount ( method )

Superclass method that displays a confirm message for deactivating a user's account.

=head3 method

Auth method that the form for creating users should call
   
=cut

sub deactivateAccount {
   my $self = shift;
   my $method = $_[0];
   return WebGUI::Privilege::vitalComponent() if($self->userId eq '1' || $self->userId eq '3');
   return WebGUI::Privilege::adminOnly() if(!$session{setting}{selfDeactivation});
   my %var; 
  	$var{title} = WebGUI::International::get(42);
   	$var{question} =  WebGUI::International::get(60);
   	$var{'yes.url'} = WebGUI::URL::page('op=auth&method='.$method);
	$var{'yes.label'} = WebGUI::International::get(44);
   	$var{'no.url'} = WebGUI::URL::page();
	$var{'no.label'} = WebGUI::International::get(45);
	return WebGUI::Asset::Template->new("PBtmpl0000000000000057")->process(\%var);
}

#-------------------------------------------------------------------

=head2 deactivateAccount ( method )

Superclass method that performs general functionality for deactivating accounts.
  
=cut

sub deactivateAccountConfirm {
   my $self = shift;
   return WebGUI::Privilege::vitalComponent() if($self->userId eq '1' || $self->userId eq '3');
   my $u = $self->user;
   $u->status("Selfdestructed");
   WebGUI::Session::end($session{var}{sessionId});
   WebGUI::Session::start(1);   
}

#-------------------------------------------------------------------

=head2 deleteParams (  )

Removes the user's authentication parameters from the database for all authentication methods. This is primarily useful when deleting the user's account.

=cut

sub deleteParams {
   my $self = shift;
   WebGUI::SQL->write("delete from authentication where userId=".quote($self->userId));
}

#-------------------------------------------------------------------

=head2 displayAccount ( method [,vars] )

Superclass method that performs general functionality for viewing editable fields related to a user's account.

=head3 method

Auth method that the form for updating a user's account should call
   
=head3 vars
   
Array ref of template vars from subclass
   
=cut

sub displayAccount {
   my $self = shift;
   my $method = $_[0];
   my $vars = $_[1];
   
   $vars->{title} = WebGUI::International::get(61);
   
   $vars->{'account.form.header'} = WebGUI::Form::formHeader({});
   $vars->{'account.form.header'} .= WebGUI::Form::hidden({"name"=>"op","value"=>"auth"});
   $vars->{'account.form.header'} .= WebGUI::Form::hidden({"name"=>"method","value"=>$method});
   if($session{setting}{useKarma}){
      $vars->{'account.form.karma'} = $session{user}{karma};
	  $vars->{'account.form.karma.label'} = WebGUI::International::get(537);
   }
   $vars->{'account.form.submit'} = WebGUI::Form::submit({});
   $vars->{'account.form.footer'} = WebGUI::Form::formFooter();
   
   $vars->{'account.options'} = WebGUI::Operation::Shared::accountOptions();
   return WebGUI::Asset::Template->new($self->getAccountTemplateId)->process($vars);
}

#-------------------------------------------------------------------

=head2 displayLogin ( [method,vars] )

Superclass method that performs general functionality for creating new accounts.

=head3 method

Auth method that the form for performing the login routine should call
   
=head3 vars
   
Array ref of template vars from subclass
   
=cut

sub displayLogin {
    	my $self = shift;
	my $method = $_[0] || "login";
	my $vars = $_[1];
	unless ($session{form}{op} eq "auth") {
	   	WebGUI::Session::setScratch("redirectAfterLogin",WebGUI::URL::getSiteURL().WebGUI::URL::getScriptURL().$session{env}{PATH_INFO}.”?”.$session{env}{QUERY_STRING});
	}
	$vars->{title} = WebGUI::International::get(66);
	my $action;
        if ($session{setting}{encryptLogin}) {
                $action = WebGUI::URL::page(undef,1);
                $action =~ s/http:/https:/;
        }
	$vars->{'login.form.header'} = WebGUI::Form::formHeader({action=>$action});
    	$vars->{'login.form.hidden'} = WebGUI::Form::hidden({"name"=>"op","value"=>"auth"});
	$vars->{'login.form.hidden'} .= WebGUI::Form::hidden({"name"=>"method","value"=>$method});
	$vars->{'login.form.username'} = WebGUI::Form::text({"name"=>"username"});
    	$vars->{'login.form.username.label'} = WebGUI::International::get(50);
    	$vars->{'login.form.password'} = WebGUI::Form::password({"name"=>"identifier"});
    	$vars->{'login.form.password.label'} = WebGUI::International::get(51);
	$vars->{'login.form.submit'} = WebGUI::Form::submit({"value"=>WebGUI::International::get(52)});
	$vars->{'login.form.footer'} = WebGUI::Form::formFooter();
	$vars->{'anonymousRegistration.isAllowed'} = ($session{setting}{anonymousRegistration});
	$vars->{'createAccount.url'} = WebGUI::URL::page('op=auth&method=createAccount');
	$vars->{'createAccount.label'} = WebGUI::International::get(67);
	return WebGUI::Asset::Template->new($self->getLoginTemplateId)->process($vars);
}

#-------------------------------------------------------------------

=head2 editUserForm (  )

Creates user form elements specific to this Auth Method.

=cut

sub editUserForm {
   #Added for interface purposes only.  Needs to be implemented in the subclass.
}

#-------------------------------------------------------------------

=head2 editUserFormSave ( properties )

Saves user elements unique to this authentication method

=cut

sub editUserFormSave {
   my $self = shift;
   $self->saveParams($self->userId,$self->authMethod,$_[0]);
}

#-------------------------------------------------------------------

=head2 error ( [errorMsg] )

Sets or returns the error currently stored in the object

=cut

sub error {
   my $self = shift;
   return $self->{error} if (!$_[0]);
   $self->{error} = $_[0];
}

#-------------------------------------------------------------------

=head2 getAccountTemplateId ()

This method should be overridden by the subclass and should return the template ID for the display/edit account screen.

=cut

sub getAccountTemplateId {
	return "PBtmpl0000000000000010";
}

#-------------------------------------------------------------------

=head2 getAccountTemplateId ()

This method should be overridden by the subclass and should return the template ID for the create account screen.

=cut

sub getCreateAccountTemplateId {
	return "PBtmpl0000000000000011";
}

#-------------------------------------------------------------------

=head2 getAccountTemplateId ()

This method should be overridden by the subclass and should return the template ID for the login screen.

=cut

sub getLoginTemplateId {
	return "PBtmpl0000000000000013";
}

#-------------------------------------------------------------------

=head2 getParams ()

Returns a hash reference with the user's authentication information.  This method uses data stored in the instance of the object.

=cut

sub getParams {
    my $self = shift;
	my $userId = $_[0] || $self->userId;
	my $authMethod = $_[1] || $self->authMethod;
	return WebGUI::SQL->buildHashRef("select fieldName, fieldData from authentication where userId=".quote($userId)." and authMethod=".quote($authMethod));
}

#-------------------------------------------------------------------

=head2 getSetting (  setting  )

Returns a setting for this authMethod instance.  If none is specified, returns the system authMethod setting

=head3 setting

Specify a setting to retrieve

=cut

sub getSetting {
	my $self = shift;
	my $setting = $_[0];
	$setting = lc($self->authMethod).ucfirst($setting);
	return $session{setting}{$setting};
}

#-------------------------------------------------------------------

=head2 init ( )

Initialization function for these auth routines.  Default is a superclass function called displayLogin.
Override this method in your subclass to change the initialization for custom authentication methods

=cut

sub init {
   my $self = shift;
   return $self->displayLogin;
}

#-------------------------------------------------------------------

=head2 isCallable ( method )

Returns whether or not a method is callable

=cut

sub isCallable {
   my $self = shift;
   return isIn($_[0],@{$self->{callable}})
}


#-------------------------------------------------------------------

=head2 login ( )

Superclass method that performs standard login routines.  This is what should happen after a user has been authenticated.
Authentication should always happen in the subclass routine.

=cut

sub login {
   my $self = shift;
   my ($cmd, $uid, $u, $authMethod,$msg,$userData,$expireDate);
   
   #Create a new user
   $uid = $self->userId;
   $u = WebGUI::User->new($uid);
   WebGUI::Session::convertVisitorToUser($session{var}{sessionId},$uid);
   $u->karma($session{setting}{karmaPerLogin},"Login","Just for logging in.") if ($session{setting}{useKarma});
   _logLogin($uid,"success");
   
   if ($session{scratch}{redirectAfterLogin}) {
		WebGUI::HTTP::setRedirect($session{scratch}{redirectAfterLogin});
	  	WebGUI::Session::deleteScratch("redirectAfterLogin");
   }
   return "";
}

#-------------------------------------------------------------------

=head2 logout ( )

Superclass method that performs standard logout routines.

=cut

sub logout {
	my $self = shift;
   WebGUI::Session::end($session{var}{sessionId});
   WebGUI::Session::start(1);
	my $u = WebGUI::User->new(1);
	$self->{user} = $u;
   return "";
}

#-------------------------------------------------------------------

=head2 new ( authMethod [,userId,callable] )

Constructor.

=head3 authMethod
  
This object's authentication method
  
=head3 userId

userId for the user requesting authentication.  This defaults to $session{user}{userId}
  
=head3 callable

Array reference of methods allowed to be called externally;  

=cut

sub new {
	my $self = {};
	shift;
	
	#Initialize data
	$self->{authMethod} = $_[0];
	my $userId = $_[1] || $session{user}{userId};
	my $u = WebGUI::User->new($userId);
	$self->{user} = $u;
	$self->{error} = "";
	$self->{profile} = ();
	$self->{warning} = "";
	my @callable = ('init', @{$_[2]});
	$self->{callable} = \@callable;
	bless($self);
	return $self;
}

#-------------------------------------------------------------------

=head2 profile ()

Sets or returns the Profile hash for a user.

=cut

sub profile {
  my $self = shift;
  return $self->{profile} if ($_[0]);
  $self->{profile} = $_[0];
}



#-------------------------------------------------------------------

=head2 setCallable ( callableMethods )

adds elements to the callable routines list.  This list determines whether or not a method in this instance is 
allowed to be called externally

=head3 callableMethods

Array reference containing a list of methods for this authentication instance that can be called externally

=cut

sub setCallable {
   my $self = shift;
   my @callable = @{$self->{callable}};
   @callable = (@callable,@{$_[0]});
}

#-------------------------------------------------------------------

=head2 saveParams ( userId, authMethod, data )

Saves the user's authentication parameters to the database.

=head3 userId

Specify a user id.

=head3 authMethod

Specify the authentication method to save these paramaters under.

=head3 data

A hash reference containing parameter names and values to be saved.

=cut

sub saveParams {
    my $self = shift;
	my ($uid, $authMethod, $data) = @_;
	foreach (keys %{$data}) {
       WebGUI::SQL->write("delete from authentication where userId=".quote($uid)." and authMethod=".quote($authMethod)." and fieldName=".quote($_));
   	   WebGUI::SQL->write("insert into authentication (userId,authMethod,fieldData,fieldName) values (".quote($uid).",".quote($authMethod).",".quote($data->{$_}).",".quote($_).")");
    }
}

#-------------------------------------------------------------------

=head2 user ( [user] )

Sets or Returns the user object stored in the wobject

=cut

sub user {
   my $self = shift;
   return $self->{user} if (!$_[0]);
   $self->{user} = $_[0];
}

#-------------------------------------------------------------------

=head2 userId ( )

Returns the userId currently stored in the object

=cut

sub userId {
   my $self = shift;
   my $u = $self->user;
   return $u->userId;
}

#-------------------------------------------------------------------

=head2 username ( )

Returns the username currently stored in the object

=cut

sub username {
   my $self = shift;
   my $u = $self->user;
   return $u->username;
}

#-------------------------------------------------------------------

=head2 validUsername ( username )

Validates the a username.

=cut

sub validUsername {
   my $self = shift;
   my $username = WebGUI::Macro::negate($_[0]);
   my $error = "";
   
   if($self->_isDuplicateUsername($username)){
      $error .= $self->error;
   }
   
   if(!$self->_isValidUsername($username)){
      $error .= $self->error;
   }
   
   $self->error($error);
   return $error eq "";
}

#-------------------------------------------------------------------

=head2 warning ( [warningMsg] )

Sets or Returns a warning in the object

=cut

sub warning {
   my $self = shift;
   return $self->{warning} if (!$_[0]);
   $self->{warning} = $_[0];
}

1;
