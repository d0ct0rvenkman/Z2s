# Z2s
Zkillboard to Slack

Z2s is a small perl script which will regularly check and post killmails for specified criteria with data gathered from the Zkillboard API. It can follow arbitrary api endpoints, and also give slightly more in-depth information for alliances, corporations, or characters that are specifically tracked.

# Configuration
You will want to edit several variables before starting :

- $slackURL : You need to put there the incoming webhook URL from Slack. You can create one on Slack in the Integrations menu (you need to be admin for it)
- $slack_Channel : The channel where you want the bot to post your stuff
- $slack_Username : If you do not like rampaging killbots in your channel, alter this to something more to your liking. 
- @api_endpoints : any interesting API endpoints you want to follow
- $tracked_alliances : alliance IDs for any alliances whose kills you would like to see
- $tracked_corporations : corporation IDs for any corporations whose kills you would like to see
- $tracked_characters : character IDs for any characters whose kills you would like to see

# To Do
- Break out configurable settings into a configuration file instead of editing the script directly
- Make script capable of using an arbitrary config file so multiple copies of the script with different configurations can be run easily
- Limit the number of "Bros Involved" shown in kill display to keep messages from stretching for miles. (slack may already do this automatically.)
- Profit?
