# DisableInactiveUsers
Ruby script to disable inactive users <I>(I DIDN'T WRITE THIS FROM SCRATCH! Borrowed from a Private Repo in RallyTechServices)</I><br>
I also converted this script to an executable using "ocra" -- see <a href="http://ocra.rubyforge.org">ocra.rubyforge.org</a><br>
The "DisableInactiveUsers.exe" file can be executed in a Windows environment without the need to set up a Ruby environment.<br><br>
In order to make the Ruby script work as an executable with ocra, a couple of changes were needed:
<UL>
<LI>Explicity "require" the rally_api and logger gems at the top of the file (so they are recognized and loaded by ocra)</LI>
<LI>Prompt for the URL, user login, and password for Agile Central rather than having these values hard-coded or read from a file</LI>
</UL>
