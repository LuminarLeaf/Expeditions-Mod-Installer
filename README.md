# Expeditions-Mod-Installer
Install mods for "Expeditions: A Mudrunner Game" from Mod.io

## Mods installer from mod.io to Expeditions
The installer allows you to download mods from mod.io in semi-automatic mode. Once you complete all the steps according to the instructions, you will be able to subscribe to the desired mods, then the installer will download them itself.

Tested on game builds from Steam. Epic Games Store is not tested, you may create a pull request adding the support for it if you want.

## How to use

1. Download/Clone the repository on your computer.
2. Register for an account on [mod.io](https://mod.io/).
3. Go to [/me/access](https://mod.io/me/access).
4. Click on accept API terms (idr if this is necessary for getting o-auth token but eh do it anyways).
5. Below that there will be a OAuth2 section, give a name for a client(can be anything) and click on Create Client.
6. Then in the token field, write a new name and generate a token.
7. Rename the .env_example file to .env.
8. Copy the token and paste it the .env file in the `ACCESS_TOKEN` field. Remember that the token is only shown once so I recommend you to save it in a separate file too.
9. Open the `.env` file and change the `MODS_DIR` and `USER_PROFILE` fields to the correct paths.
   - MODS_DIR: `C:\Users\USER_NAME\Documents\My Games\Expeditions\base\Mods\.modio\mods`
   - USER_PROFILE: `C:\Program Files (x86)\Steam\userdata\USER_ID\1623730\remote\user_profile.cfg`
10. Replace the `user_profile.cfg` file with the one in the repository.
11. Before you run the script for the first time, you need to clear out the mods you may have installed from other sources/methods (if you have any). To do this, go to the `MODS_DIR` path and delete all the folders and files in the `mods` folder. If there are any mods in the mods folder with the same id as the mods you are going to download, the installer will not download them thinking that they are already there and this may not work correctly.
12. Subscribe to the mods you want to download on the mod.io website.
13. Run the `ModIO_EXP.ps1` file (you can run it by right-clicking on it and selecting "Run with PowerShell") and wait until all the mods you subscribed to are downloaded.
14. Start the game and wait a few seconds for the game to load all the mods you have downloaded, or go to "LOAD GAME" and exit back to the main menu to activate the "MOD BROWSER" item.
15. Go to "MOD BROWSER" and enable the necessary mods. The vehicles will become available in the store, the custom maps will become available in "Custom scenarios".

After you subscribe to a new mod or unsubscribe from an existing one, run the installer again to download the new mods or remove the old ones. When unsubscribing, the script will not remove the files from the disk but move them to the cache folder. If you subscribe to the mod again, then after running the installer the mod will not be downloaded again, but will be moved from the cache folder to the mods folder, after that you will need to manually turn it on again in the game in "MOD BROWSER".

The installer will not remove the mods from the cache folder, so if you need to remove them, you will need to do it with the argument given below.

## Arguments

- `--clear-cache` or `-c` - Clear the cache folder. This will remove all the mods from the cache folder.
- `--update` or `-u` - Update the mods. This will download new versions of the mods you have already downloaded if they are available (without this argument, only a message about the availability of new versions will be displayed).
- `--version` or `-v` - Show the version of the script.

## Issues

If you have any issues, please create an issue on the GitHub repository.

## Other notes

This script is based on my other script for the game "Snowrunner", which can be found [here](https://github.com/AryanVerma1024/SnowRunner_mod_installer).

## Credits

- [Equdevel/Snowrunner_mod_installer](https://github.com/equdevel/SnowRunner_mod_installer) - The original script for Snowrunner written in python.