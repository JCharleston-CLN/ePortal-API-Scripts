Code by Jamie Charleston, Director of Global Sales Engineering, TuxCare, a CloudLinux Software Inc company.

This script and its associated files are provided "as is", without warranty of any kind — express or implied. 
By using this code, you acknowledge that:

- You are responsible for understanding what the script does before running it.
- The author(s) are not liable for any damage, data loss, downtime, misconfiguration, 
  or unintended behavior resulting from the use or misuse of this script.
- This script may require modification to suit your environment and use case.
- No guarantees are made regarding the correctness, performance, or security of the code.

Use responsibly and test thoroughly before using in a production environment.


                                      ePortal_ Multi_Schedular.sh

This script is a bash script that allows for configuring cronjobs in advance on one or multiple eportals.
Edit the script section 1 to configure each eportals Name in [] along with Base_URL and API_Key. You can create more
variables if needed or comment out those you do not need.

Edit the script section 2 to configure the exact names of your ePortal feeds across your ePortal(s)


This script performs 3 jobs:
- register ePortal Feed Oportations via API for specific patchset, date, time, feed, and action into Cron schedular
- Allow you to see all schedule opportations and clean them up easily after jobs have been run
- The schedule API calls also process through this script, giving a single script for all your Feed Scheduling Needs



                                        Example #1 Create Schedule:


[root@kcdeemo ~]# sh ePortal_Multi_Schedular.sh 

What would you like to do?
1) Create/Schedule a new patchset task
2) Clean existing scheduled tasks
 Enter 1 or 2: 1

Scheduling a new task...

Current server date and time: 2025-04-10 20:02:56

Enter the patchset (e.g., K20250420_03): K20250219_05

Available feed names: main Production Staging DevOps
Enter the target feed(s), comma-separated (e.g., test,production): Production,Staging 
Enter the action (enable, disable, enable-upto, undeploy-downto): enable
Enter the product (kernel, user, qemu, db) [default: kernel]: kernel

Available API endpoints:
  → Master
  → dev
  → staging
Choose the API endpoint to use: Jamie
Enter the date to run the task (YYYY-MM-DD): 2025-04-10
Enter the time to run the task (24hr format, HH:MM): 20:04

Task scheduled for 2025-04-10 at 20:04:
   → sh /root/ePortal_Multi_Schedular.sh "K20250219_05" "Production,Staging" "enable" "kernel" "Jamie"


                                         Example #2 Clean existing Scheduled Task

[root@kcdeemo ~]# sh ePortal_Multi_Schedular.sh 

What would you like to do?
1) Create/Schedule a new patchset task
2) Clean existing scheduled tasks
 Enter 1 or 2: 2

Cleaning up scheduled tasks...
Current scheduled tasks:
1 . 58 19 10 04 * sh /root/ePortal_Multi_Schedular.sh "K20250310_11" "Production" "enable" "kernel" "Master"
2 . 00 20 10 04 * sh /root/ePortal_Multi_Schedular.sh "K20250310_11" "Staging" "enable-upto" "kernel" "Master"

Enter the number(s) of the task(s) to remove (e.g., 1 2 3), or leave blank to cancel:
1 2
Selected tasks removed from crontab.

