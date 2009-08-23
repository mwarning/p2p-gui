
DMD = dmd
GDC = gdc
LDC = ldc

ADD_DMD_PARAMS = -version=JAY_GUI -version=PLEX_GUI -version=CLUTCH_GUI -version=MLDONKEY -version=AMULE -version=RTORRENT -version=GIFT -version=TRANSMISSION
ADD_GDC_PARAMS = -fversion=JAY_GUI -fversion=PLEX_GUI -fversion=CLUTCH_GUI -fversion=MLDONKEY -fversion=AMULE -fversion=RTORRENT -fversion=GIFT -fversion=TRANSMISSION
ADD_LDC_PARAMS = -d-version=JAY_GUI -d-version=PLEX_GUI -d-version=CLUTCH_GUI -d-version=MLDONKEY -d-version=AMULE -d-version=RTORRENT -d-version=GIFT -d-version=TRANSMISSION

DMD_RELEASE = #-release -O #-debug -gc
GDC_RELEASE = #-O3 -finline-functions -frelease #-fdebug
LDC_RELEASE = #-release #-d-debug

#-L-lbfd //for debugging with jive
LIBS_POSIX_DMD = -L-L/usr/lib -I/usr/include -L-lz -L-lssl
#-defaultlib=tango-base-dmd -debuglib=tango-base-dmd -L-ltango-user-dmd
LIBS_POSIX_GDC = -lgtango -lz -lssl
LIBS_POSIX_LDC = -L-L/usr/lib -I/usr/include -L-lz -L-lssl
#-L-ltango-base-ldc -L-ltango-user-ldc
LIBS_WINDOWS_DMD = -L+zlib.lib -L+ws2_32.lib
#-defaultlib=tango-base-dmd -debuglib=tango-base-dmd -L-ltango-user-dmd


BASE_FILES = webserver/HttpServer.d \
	webserver/HttpResponse.d \
	webserver/HttpRequest.d \
	utils/Utils.d \
	utils/GeoIP.d \
	utils/Timer.d \
	utils/Selector.d \
	utils/Storage.d \
	utils/Debug.d \
	utils/json/JsonAdditional.d \
	utils/json/JsonParser.d \
	utils/json/JsonBuilder.d \
	webcore/Main.d \
	webcore/MainUser.d \
	webcore/UserManager.d \
	webcore/DiskFile.d \
	webcore/Webroot.d \
	webcore/SettingsWrapper.d \
	webcore/Dictionary.d \
	webcore/JsonRPC.d \
	webcore/Session.d \
	webcore/SessionManager.d \
	webcore/ClientManager.d \
	webcore/Logger.d \
#jive/stacktrace.d \
#jive/demangle.d \
#jive/c/ucontext.d \

API_FILES = api/Client.d \
	api/Host.d \
	api/Node.d \
	api/Node_.d \
	api/File.d \
	api/File_.d \
	api/Meta.d \
	api/Setting.d \
	api/Connection.d \
	api/User.d \
	api/User_.d \
	api/Search.d \
	api/Search_.d \

#aMule
AMULE_FILES = clients/amule/aMule.d \
	clients/amule/ECPacket.d \
	clients/amule/ECTag.d \
	clients/amule/ECCodes.d \
	clients/amule/RLE_Data.d \
	clients/amule/Utf8_Numbers.d \
	clients/amule/model/AFileInfo.d \
	clients/amule/model/AServerInfo.d \
	clients/amule/model/AResultInfo.d \
	clients/amule/model/ASearchInfo.d \
	clients/amule/model/APreference.d \
	clients/amule/model/AClientInfo.d \

#Applejuice
AJ_FILES = clients/applejuice/AppleJuice.d \
	clients/applejuice/AJMessage.d \

#Hydranode
HN_FILES = clients/hydranode/Hydranode.d \
	clients/hydranode/opcodes.d \
	clients/hydranode/model/HNDownload.d \
	clients/hydranode/model/HNNetwork.d \
	clients/hydranode/model/HNModule.d \
	clients/hydranode/model/HNSearch.d \
	clients/hydranode/model/HNResult.d \
	clients/hydranode/model/HNSharedFile.d \

#giFT
GIFT_FILES = clients/gift/giFT.d \
	clients/gift/giFTParser.d \
	clients/gift/model/giFTFile.d \
	clients/gift/model/giFTSearch.d \
	clients/gift/model/giFTResult.d \
	clients/gift/model/giFTNetwork.d \

#MLDonkey
MLDONKEY_FILES = clients/mldonkey/MLDonkey.d \
	clients/mldonkey/InBuffer.d \
	clients/mldonkey/OutBuffer.d \
	clients/mldonkey/MLUtils.d \
	clients/mldonkey/model/MLConsoleLine.d \
	clients/mldonkey/model/MLTags.d \
	clients/mldonkey/model/MLAddr.d \
	clients/mldonkey/model/MLFileInfo.d \
	clients/mldonkey/model/MLNetworkInfo.d \
	clients/mldonkey/model/MLFileFormat.d \
	clients/mldonkey/model/MLServerInfo.d \
	clients/mldonkey/model/MLClientInfo.d \
	clients/mldonkey/model/MLClientKind.d \
	clients/mldonkey/model/MLClientState.d \
	clients/mldonkey/model/MLSearch.d \
	clients/mldonkey/model/MLResult.d \
	clients/mldonkey/model/MLSharedFile.d \
	clients/mldonkey/model/MLSetting.d \
	clients/mldonkey/model/MLPartFile.d \

#rTorrent
RTORRENT_FILES = clients/rtorrent/rTorrent.d \
	clients/rtorrent/XmlOutput.d \
	clients/rtorrent/XmlInput.d \
	clients/rtorrent/rDownload.d \
	clients/rtorrent/rSetting.d \
	clients/rtorrent/rTracker.d \
	clients/rtorrent/rPeer.d \

#Transmission
TRANSMISSION_FILES = clients/transmission/Transmission.d \
	clients/transmission/TTorrent.d \
	clients/transmission/TTracker.d \
	clients/transmission/TFile.d \
	clients/transmission/TPeer.d \

#MultiUser
MU_FILES = clients/multiuser/MultiUser.d \


#Plex html gui (server side)
PLEX_GUI_FILES = webguis/plex/PlexGui.d \
	webguis/plex/HtmlElement.d \
	webguis/plex/HtmlUtils.d \
	webguis/plex/HtmlSettings.d \
	webguis/plex/HtmlFileBrowser.d \
	webguis/plex/HtmlDownloads.d \
	webguis/plex/HtmlServers.d \
	webguis/plex/HtmlClients.d \
	webguis/plex/HtmlTitlebar.d \
	webguis/plex/HtmlConsole.d \
	webguis/plex/HtmlContainer.d \
	webguis/plex/HtmlSearches.d \
	webguis/plex/HtmlPageRefresh.d \
	webguis/plex/HtmlUserManagement.d \
	webguis/plex/HtmlClientSettings.d \
	webguis/plex/HtmlModuleSettings.d \
	webguis/plex/HtmlUserSettings.d \
	webguis/plex/HtmlAddLinks.d \
	webguis/plex/HtmlUploads.d \
	webguis/plex/HtmlQuickConnect.d \
	webguis/plex/HtmlTranslator.d \
	webguis/plex/HtmlLogout.d \

#Jay javascript gui (client side)
JAY_GUI_FILES = webguis/jay/JayGui.d \

#Clutch javascript gui (client side), from Transmission
CLUTCH_GUI_FILES = webguis/clutch/ClutchGui.d \

CLIENT_FILES = $(MLDONKEY_FILES) $(AMULE_FILES) $(RTORRENT_FILES) $(GIFT_FILES) $(TRANSMISSION_FILES)
GUI_FILES = $(PLEX_GUI_FILES) $(JAY_GUI_FILES) $(CLUTCH_GUI_FILES) 
ALL = $(BASE_FILES) $(API_FILES) $(CLIENT_FILES) $(GUI_FILES)

default:
	@echo "Use: make dmd-linux|dmd-win|dmd-mac|ldc-linux|gdc|gdc-mac"

#Note:
# * DMD only produces 32bit binaries, it may cause linking troubles on 64bit systems when no 32bit libraries are present!

#create a 32bit x86 Linux binary
dmd-linux:
	$(DMD) -ofp2p-gui-linux $(ALL) $(DMD_RELEASE) -version=Tango $(ADD_DMD_PARAMS) $(LIBS_POSIX_DMD)

#create a 32bit (Intel) Mac binary
dmd-mac:
	$(DMD) -ofp2p-gui-mac $(ALL) $(DMD_RELEASE) -version=Tango $(ADD_DMD_PARAMS) $(LIBS_POSIX_DMD)

#create a Windows 32bit x86 binary (compiles in a MinGW/MSYS enviroment)
dmd-win:
	$(DMD).exe -ofp2p-gui-win.exe $(ALL) $(DMD_RELEASE) -version=Tango $(ADD_DMD_PARAMS) $(LIBS_WINDOWS_DMD)

#create a Linux binary
ldc-linux:
	$(LDC) -ofp2p-gui-linux $(ALL) $(LDC_RELEASE) $(ADD_LDC_PARAMS) $(LIBS_POSIX_LDC)

#create a mac universal binary
gdc-mac : clean
	$(GDC) -o p2p-gui-mac $(ALL) -arch i386 $(GDC_RELEASE) -fversion=Tango -fversion=Posix $(ADD_GDC_PARAMS) -L/SDKs/MacOSX10.4u.sdk/usr/lib -isysroot /Developer/SDKs/MacOSX10.4u.sdk $(LIBS_POSIX_GDC)

#just use posix gdc
gdc : clean
	$(GDC) -o p2p-gui $(ALL) $(GDC_RELEASE) -fversion=Tango -fversion=Posix $(ADD_GDC_PARAMS) $(LIBS_POSIX_GDC)

##causes troubles
##dmd forget symbols when we have circular dependencies
#gmui : $(ALL)
#	$(CC) -of$@ $(ALL) $(LIBS)

#%.o : %.d
#	$(CC) $(CCFLAGS) $(DEBUG) $(TANGO) -of$@ -c $<

#say: clean is no file!
.PHONY: clean

clean:
	rm -f *.o *.obj *.map
