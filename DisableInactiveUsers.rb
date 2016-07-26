require 'optparse'
require 'ostruct'
require 'logger'
require 'rally_api'
#!/usr/bin/env ruby
# ------------------------------------------------------------------------------
# SCRIPT:
#       DisableInactiveUsers
#
# PURPOSE:
#       Used to disable Rally users who have:
#           1) Not logged in for the past "X" days.
#           2) Accounts older than "X" days and they have never logged in.
#           3) If the has No-Access or Blank login date.
#       type DisableInactiveUsers.rb -h to get help.
#
# PREREQUISITES:
#       - Ruby version 1.9.3 or later.
#
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Define our constants / variables.
#
$my_util_name   = 'DisableInactiveUsers_'
$my_base_url    = 'https://rally1.rallydev.com'
$my_username    = 'user@domain.com' # Enter the username
$my_password    = '' # If empty, user will be prompted for it.
$my_version     = 'v2.0'
$my_failsafe    = false # quit after four users?


# ------------------------------------------------------------------------------
# Helper Class to help Logger output to both STOUT and to a file
# Attribution: see http://goo.gl/m7CUIC
class MultiIO
  def initialize(*targets)
     @targets = targets
  end

  def write(*args)
    @targets.each {|t| t.write(*args)}
  end

  def close
    @targets.each(&:close)
  end
end


# ------------------------------------------------------------------------------
# Set up logger.
#
def setup_logger()
  time_now = Time.new.strftime("%Y_%m_%d_%H_%M_%S")
  #logfile = $my_util_name+time_now+'.log'
  if(@display_only)
    logfile = 'ListInactiveUsers_'+time_now+'.log'
  else
    logfile = 'DisableInactiveUsers_'+time_now+'.log'
  end
  fileh = File.open(logfile, "a")
  @logger = Logger.new MultiIO.new(STDOUT, fileh)
  @logger.formatter = proc do |severity, datetime, progname, msg|
    "#{msg}\n"
  end
  @logger.info("Log file is: '#{logfile}'")
end


# ------------------------------------------------------------------------------
# Routine to perform an error exit.
# Error exit codes (must be less than or equal to zero) and text:
$ERR_EXITS = {
  ($ERR_EXIT_None     = -0)   =>  'No error, just print usage.',
  ($ERR_EXIT_NoGem    = -1)   =>  'This script needs the Ruby GEM "%s" installed before it can run.',
  ($ERR_EXIT_Fatal1   = -2)   =>  'Program had a fatal logic error (unrecognized error exit code).',
  ($ERR_EXIT_NoUsers  = -8)   =>  'The query for users returned nothing.',
  }
$ERR_ACTION = [
  $ERR_ACTION_None    = 0,    # Print nothing.
  $ERR_ACTION_Usage   = 1,    # Print the USAGE clause.
  ]

def error_exit(exit_code,action,msg='') #{ 
  # exit_code must exist, and be between -MAX and ZERO
  if exit_code.nil? || !exit_code.between?(1-$ERR_EXITS.length, 0)
    print "Error:\tUnrecognized internal exit_code: #{exit_code}\n"
    exit_code = $ERR_EXIT_Fatal1
  end

  print "Error:\t#{$ERR_EXITS[exit_code]}\n"%[msg] if exit_code != 0
  if action != 0
    print $MU
  end
  exit (exit_code)
end #} end of "def error_exit(exit_code,action)"


# ------------------------------------------------------------------------------
# Load (and maybe override with) my personal/private variables from a file.
#
def get_my_vars()
  my_vars = '../MyVars.rb'
  if FileTest.exist?( my_vars )
    @logger.info("Loading '#{my_vars}'")
    require my_vars
  else
    @logger.info("File '#{my_vars}' not found; skipping load")
  end
end


# ------------------------------------------------------------------------------
# Load the required Ruby GEMs.
#
def require_gems()
  @logger.info("Loading the required Ruby GEMs")
  failed_requires = 0
  %w{io/console rally_api}.each do |this_require|
    begin
      require this_require
      @logger.info("\trequired: '#{this_require}'")
    rescue LoadError
      @logger.info("ERROR: This script requires Ruby GEM: '#{this_require}'")
      failed_requires += 1
    end
  end
  if failed_requires > 0
    exit (-1)
  end
  return
end


# ------------------------------------------------------------------------------
# Routine to process command line options.
#
def get_args()
    # Add help as argument if no argument is given.
    ARGV << '-h' if ARGV.empty?

    #This flag makes sure by default all users will NOT be disabled. 
    @display_only = true

    @options = OpenStruct.new
    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: DisableInactiveUsers.rb [options]"
            opts.separator ""
      opts.separator "Specific options:"
      opts.on('-d', '--days TOTAL_DAYS', Integer, 'Total number of days that the users did not access the system') { |o| @options.days = o }
      opts.on('-t', '--type TYPE_OF_REQUEST', String, 'Type of Request. No-Access or Blank-Last-Login') { |o| @options.type = o }
      opts.on('-R', '--reallydoit', String, 'When this option is given the users will be disabled') do |o|
        # this flag disables all the users. 
        @display_only = false
      end

      #{ |o| @options.mode = o }
      opts.on("-h", "--help", "Prints this help") do
        puts opts
        exit
      end
    end


  begin
    optparse.parse!
  rescue OptionParser::InvalidOption, OptionParser::MissingArgument, OptionParser::InvalidArgument      #
    puts $!.to_s                                                           # Friendly output when parsing fails
    puts optparse                                                          #
    exit                                                                   #
  end                 

 
end


# ------------------------------------------------------------------------------
# Routine to connect to Rally.
#
def connect_to_rally()
  # Be sure Rally URL is good (removing trailing '/' if present and add '/slm' if needed)
   $my_base_url = $my_base_url.chomp('/')
   $my_base_url << '/slm' if !$my_base_url.end_with?('/slm')

  # If there is no password yet, read from user (with no-echo).
  if $my_password.nil? || $my_password.empty?
    @logger.info("Password for '#{$my_username}' at '#{$my_base_url}' not found, please enter now")
    print 'password: '
    $my_password = STDIN.noecho(&:gets).chomp.strip
  end

  @logger.info("Connecting to Rally at:")
  @logger.info("\tBaseURL  : <#{$my_base_url}>")
  @logger.info("\tUserName : <#{$my_username}>")
  @logger.info("\tPassword : <#{$my_password.gsub(/./,'*')}>")
  @logger.info("\tVersion  : <#{$my_version}>")

  $my_headers         = RallyAPI::CustomHttpHeader.new()
  $my_headers.name    = 'DisableUsers.rb'
  $my_headers.vendor  = 'Rally-Technical-Services'
  $my_headers.version = '1.2345'

  config = {  :base_url   => $my_base_url,
              :username   => $my_username,
              :password   => $my_password,
              :version    => $my_version,
              :headers    => $my_headers
  }

  @rally = RallyAPI::RallyRestJson.new(config)
  return @rally
end


# ------------------------------------------------------------------------------
# Query for our desired data.
#
def get_all_users()
  @logger.info("Query Rally for all Users")
  @all_users = @rally.find(
                RallyAPI::RallyQuery.new(
                    :type           => :user,
                    :query_string   => '(ObjectID > 0)',
                    :fetch          => 'CreationDate,
                                        Disabled,
                                        EmailAddress,
                                        LastLoginDate,
                                        ObjectID,
                                        UserName,
                                        SubscriptionPermission,
                                        '.delete(' ').delete("\n")))

  # Verify we got back the kind of data we expected.
  if @all_users.count < 1  # Did we find too few?
    error_exit($ERR_EXIT_NoUsers)
  end
  @logger.info("Found a total of <#{@all_users.total_result_count}> users in this subscription")

  
  # Process list of all users, adding a "DaysIdle" field.
  @all_users.each_with_index do |this_user, this_index|
    time_now = Date.parse(Time.now.iso8601)
    if this_user[:LastLoginDate].nil?
      this_user[:LastLoginDate] = ''
      time_last = Date.parse(this_user[:CreationDate])
    else
      time_last = Date.parse(this_user[:LastLoginDate])
    end
    days_idle = (time_now - time_last).to_i
    this_user[:DaysIdle] = days_idle
    #@logger.info("UserName='#{this_user[:UserName]}' days_idle='#{days_idle}' time_now=#{time_now} time_last=#{time_last}")
  end

  # ------------------------------------------------------------------------------
  # Sort the users by two fields:
  #   primary - number of days since last login (DaysIdle)
  #   secondary - creation date of the user (CreationDate)
  # User's who've never logged in have a 'DaysIde=9999' (from above). This script
  # is used to find "disable candidates" in shops which have no available seats.
  # The "never logged in" users are valid candidates, obviously, however it is
  # preferable to disable an account created years ago rather than one created
  # 2 seconds ago.
  #
  @sorted_users = @all_users.sort do |a, b|
    [b[:LastLoginDate], a[:CreationDate]] <=> [a[:LastLoginDate], b[:CreationDate]]
  end

  return @all_users
end


# ------------------------------------------------------------------------------
# Create a array of "eligible to be diabled" users only.
#
def get_eligible_users()
  @eligible_users = Array.new
  user_cnt_e = 0
  user_cnt_d = 0
  @sorted_users.each_with_index do |this_user, this_index|
    if this_user[:DaysIdle] >= @options.days.to_i
      if this_user[:Disabled]
        # only count disabled accounts, they are not "eligible" for disablement
        user_cnt_d+=1
      else
        if @options.type == 'No-Access' || @options.type == 'Blank-Last-Login'
          if @options.type == 'No-Access' && this_user[:SubscriptionPermission] == 'No Access'
            user_cnt_e+=1
            @eligible_users.push(this_user)
          end
          
          if @options.type == 'Blank-Last-Login' && this_user[:LastLoginDate]==''
            user_cnt_e+=1
            @eligible_users.push(this_user)
          end
        else
            user_cnt_e+=1
            @eligible_users.push(this_user)
        end  

      end
    end
  end #}

  if @eligible_users.length < 1
    @logger.info("No eligible users found; nothing to do; exiting")
    exit
  else
    @logger.info("There are <#{@eligible_users.length}> accounts eligible to be disabled")
  end
end


# ------------------------------------------------------------------------------
# Process all the eligible users.
#
def process_eligible_users()


  #@logger.info("Inside process_eligible_users")
  @logger.info("display_only mode - #{@display_only}")
  @users_disabled = Array.new
  if @display_only == true #{
    # --------------------------------------------------------------------------
    # We are only going to pretty-print all eligible users.
    #
    @logger.info("The following are 'Enabled' user accounts which have either:")
    @logger.info("    - a LastLoginDate (or CreationDate if LastLoginDate was blank) greater than or equal to '#{@options.days.to_i}' days")
    @logger.info("    - or never logged on and were created more than '#{@options.days.to_i}' days ago")

    if @options.type == 'No-Access'
      @logger.info("    - and the user has No-Access")
    end
    if @options.type == 'Blank-Last-Login'
      @logger.info("    - and the LastLoginDate was blank")
    end
    
    user_cnt_e = 0
    user_cnt_d = 0
    tot = 0

    print_blank_line()
    print_header()


    @eligible_users.each_with_index do |user, index|
      
      print_user_rec(user,index)
    end

    print_header()
    print_blank_line()

  else
    # --------------------------------------------------------------------------
    # We are going to disable the eligible users.
    #
    print_blank_line()

    @logger.info("THE FOLLOWING USERS HAVE BEEN DISABLED!!")

    print_blank_line()
    print_header()
    @eligible_users.each_with_index do |this_user, this_index| #{
      unless $my_failsafe == true && this_index > 3    #{ A failsafe for testing... do only the first 4 users.



        #@logger.info("Disabling user: Username:<#{this_user[:UserName]}>,  EmailAddress:<#{this_user[:EmailAddress]}>,  ObjectID:<#{this_user[:ObjectID]}>")
  
        # ----------------------------------------------------------------------
        # Attempt to disable the user.
        #
        begin #{
          this_UpdatedUser = @rally.update('User', this_user[:ObjectID], {:Disabled => true})
        rescue => ex
          @logger.info("Could not update user: '#{ex.message}'")
          exit (-1)
        end #} end of "begin"
   
        # ----------------------------------------------------------------------
        # Report status of disable.
        #

        if this_UpdatedUser[:Disabled] == true #{
            this_user[:Disabled] = true
            print_user_rec(this_user,this_index)
        else
          @logger.info("ERROR:\tuser could NOT be disabled: Username:<#{this_User[:UserName]}>,  EmailAddress:<#{this_User[:EmailAddress]}>,  ObjectID:<#{this_User[:ObjectID]}>")
        end #} end of "if this_UpdatedUser[:Disabled] == true"
  

      else
        @logger.info("Skipping this user because variable $my_failsafe is true: #{this_User[:UserName]}")
      end #} end of "unless $my_failsafe != true && this_INDX > 0"

    end #} end of "eligible_users.each_with_index do |this_User, this_INDX|"
    print_header()
    print_blank_line()
  end #} end of "if @display_only == true"
end

def print_user_rec(user,index)

      msg =       '%-03d '   %   [index+1]
      msg = msg + '%-33s '   %   [user[:UserName]]
      msg = msg + '%-33s '   %   [user[:EmailAddress]]
      msg = msg + '%-10s '   %   [user[:CreationDate][0..9]]
      msg = msg + '%-10s '   %   [user[:LastLoginDate][0..9]]
      msg = msg + '%+4s '    %   [user[:DaysIdle]]
      msg = msg + '%+8s '    %   [user[:SubscriptionPermission]]
      msg = msg + '%+5s '    %   [user[:Disabled]]
      @logger.info(msg)

end

def print_blank_line()
  @logger.info(' ');
end


def print_header()
   # header info

    head1 = '    User                              Email                             Creation   LastLogin  Days Subscription   Disabled?'
    head2 = '    Name                              Address                           Date       Date       Idle Permission              '
    head3 = '--- --------------------------------- --------------------------------- ---------- ---------- ---- -------------- ---------'

    @logger.info(head3)
    @logger.info(head1)
    @logger.info(head2)
    @logger.info(head3)
end

# ------------------------------------------------------------------------------
# MAIN
#

    get_args()
    setup_logger()
    get_my_vars()
    require_gems()
    connect_to_rally()
    get_all_users()
    get_eligible_users()
    process_eligible_users()

    # if @users_disabled.length > 0
    #   @logger.info("All done; the following users were disabled:")
    #   @logger.info("#{@users_disabled.join('  ')}")
    # else
    #   @logger.info("No user account were disabled")
    # end


# ------------------------------------------------------------------------------
# All done.
#


#end#
