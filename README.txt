P2P-GUI is a web GUI for different p2p programs
written in the D programming language.

This program combines a simple web server with gui-protocol interfaces to MLDonkey/aMule/rTorrent and giFT
and a customizeable server-side html GUI (written in D) as well as a client-side GUI (written in JavaScript).

0. About
1. Compiling
2. Change Translations 
3. Modify Included Files
4. Source Code Organisation


0. About:
    P2P-GUI is licensed under GNU General Public License.
    See gpl-3.0.txt for license details.
    Parts of this program may rely on other (GPL compatible) licenses.

   Authors:
   - Moritz Warning <mwarning@users.sourceforge.net>

1. Compiling:
    Following programs and libraries are needed in order to compile P2P-GUI:
      - a D compiler: DMD (v1.040+, http://digitalmars.com/d), LDC (http://dsource.prg/projects/ldc) or GDC-svn
      - the Tango library (svn version, http://dsource.org/projects/tango)
      - zlib library
      - OpenSSL library
      - make or rebuild (http://dsource.org/projects/DSSS)

1.1 make
    Linux:
    For compiling you need to use the Makefile.
    $make dmd-linux

    Windows:
    You also need to use MinGW+MSYS to build the binary.
    In the MSYS enviroment:
    $make dmd-win

1.2 DSSS
    You can also use DSSS (http://dsource.org/projects/dsss/):
    dsss build

1.3 Including theme files into binary
    To include all files from theme directory into the binary,
    you need to compile the ./utils/Includer.d helper program.
    Then execute it from inside of the ./webroot/ folder:
    ./Includer ../webcore/Webroot.d *

    All visible files will now included in core/Webroot.d.
    After compiling P2P-GUI, there will be no more
    disk access to ./webroot by default.



2. Change Translations:
    You have two ways to alter/add translations:

2.1 Use the html gui.
    Enable the Translator panel in the html gui and alter translations there.
    To contribute new languages or improvements, please send back the exported string.

2.2 Alter the source code.
   Translations are keep in ./core/Dictionary.d.
   The Phrase enum definitions list all phrases used in P2P-GUI.
   To alter translations just imitate the structure as for the other languages.

   In order to add a new language, you must modify ./core/Dictionary.d:
     - add a Phrase for your new language to the Phrase enum declarartion
     - add the language Phrase to all_languages
     - create a new translation by imitating the structure of the other languages

  Compile the program from your altered source.
  The new language can now be selected in the web gui.



3. Modify Included files:
    Included files are CSS, image, (static) HTML or JavaScript GUI files.
    For every release all files from the ./webroot/ directory are included into the binary.
    This is done by writing the file data into a D source file (./webcore/Webroot.d)
    with a helper tool (./utils/Includer.d).
    
    P2P-GUI ignores included files and uses an external directory
    if it's specified on the command line  ("p2p-gui -d <directory>")
    or if a directory called ./webroot/ is located in the settings directory.
    This is comfortable to edit these files and to see changes immediately.

    If you want to get the files out of the binary.
    Use "p2p-gui --write-out-files [<target_directory>]" to write all files to the disk.



4. Source Code Organisation
   P2P-GUI consists of several parts:
   - ./api/ an API to describe the p2p network environment entities and relationships
   - /clients/ - several client interfaces in on top of the api
   - ./webserver/ - a webserver to serve data
   - ./webroot/ - repository of files in for html, css, js or image files to be severed by the webserver
   - ./webguis/ - server side code for GUIs 
      - ./clutch/: interface for the Transmission web ui
      - ...
   - ./webcore/ - core files
      - Main.d: glues everything together
      - MainUser.d: implements accounts
      - MainSettings.d: wrapper for settings that conforms the api
      - DiskFile.d: wrapper for file system access that conforms the api
      - Dictionary.d: translations
      - Webroot.d: a container/accessor for files to be included into the binary
      - JsonRPC.d: a JSON RPC interface for the api, not JSON-RPC compatible yet
      - ...
   - ./utils/ - several helpful stuff
      - Selector.d: a socket handler to watch over socket events
      - Timer.d: a timer to call functions in x seconds or in intervals
      - GeoIP.d: an interface for GeoIP databases
      - Utils.d: a collection of helpful tools
      - Includer.d: a helper program to copy files and directories into a source file (Webroot.d)
      - Storage.d: a JSON based storage interface for setting files
