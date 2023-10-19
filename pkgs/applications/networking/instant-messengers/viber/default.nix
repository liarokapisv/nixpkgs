{ lib
, fetchurl
, autoPatchelfHook
, dpkg
, gst_all_1
, stdenv
, qt6
, icu66
, makeBinaryWrapper
}:

stdenv.mkDerivation {

  pname = "viber";
  version = "20.3.0.1";

  src = fetchurl {
    # Official link: https://download.cdn.viber.com/cdn/desktop/Linux/viber.deb
    url = "https://web.archive.org/web/20230906015353/https://download.cdn.viber.com/cdn/desktop/Linux/viber.deb";
    sha256 = "03h8k73b5lngpddkww8z8wdg1lrnn4rncwr9v69acsw1j1hplf30";
  };

  nativeBuildInputs = [
    makeBinaryWrapper
    autoPatchelfHook
    dpkg
  ];

  buildInputs = [
    qt6.qtbase
    qt6.full
    icu66
  ];

  dontWrapQtApps = true;

  installPhase =
    let
      gstreamerPluginPath = lib.makeSearchPath "lib/gstreamer-1.0/" [
        gst_all_1.gstreamer.out
        gst_all_1.gst-plugins-base
        gst_all_1.gst-plugins-good
        gst_all_1.gst-plugins-ugly
        gst_all_1.gst-plugins-bad
      ];
    in
    ''
      dpkg-deb -x $src $out
      mkdir -p $out/bin

      # Soothe nix-build "suspicions"
      chmod -R g-w $out

      # QT_QPA_PLATFORM_PLUGIN_PATH maybe should be set at the desktop-manager level.
      # GST_PLUGIN_PATH is specified because Qt6's QGStreamerMediaPlayer calls
      # gst_element_factory_make which in turn uses the env variable to perform the lookup.

      wrapProgram $out/opt/viber/Viber \
      --set QT_QPA_PLATFORM_PLUGIN_PATH "${qt6.full}/lib/qt-6/plugins/platforms" \
      --set QML2_IMPORT_PATH "${qt6.full}/lib/qt-6/qml" \
      --set GST_PLUGIN_PATH "${gstreamerPluginPath}" \
      --set XDG_DATA_DIRS "$out/share" \

      ln -s $out/opt/viber/Viber $out/bin/Viber

      # Remove bundled dependencies.
      rm -rf $out/opt/viber/lib

      # Remove bundled plugins.
      rm -rf $out/opt/viber/plugins

      # Symlink due to Qt6 not properly looking at QT_PLUGIN_PATH for plugin discovery in all cases.
      # Should investigate.

      ln -s "${qt6.full}/lib/qt-6/plugins" "$out/opt/viber/plugins"

      mv $out/usr/share $out/share
      rm -rf $out/usr

      # Fix the desktop link
      substituteInPlace $out/share/applications/viber.desktop \
        --replace /opt/viber/Viber Viber \
        --replace /usr/share/ $out/share/
    '';

  meta = {
    homepage = "https://www.viber.com";
    description = "An instant messaging and Voice over IP (VoIP) app";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [ jagajaga liarokapisv ];
  };
}
