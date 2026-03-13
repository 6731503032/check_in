{pkgs}: {
  channel = "stable-24.05";
  packages = [
    pkgs.jdk17
    pkgs.unzip
    pkgs.cmake
    pkgs.ninja
    pkgs.pkg-config
    pkgs.doas-sudo-shim
    pkgs.clang            # <-- This is the compiler CMake is looking for
  ];
  idx.extensions = [
    
  ];
  idx.previews = {
    previews = {
      web = {
        command = [
          "flutter"
          "run"
          "--machine"
          "-d"
          "web-server"
          "--web-hostname"
          "0.0.0.0"
          "--web-port"
          "$PORT"
        ];
        manager = "flutter";
      };
      android = {
        command = [
          "flutter"
          "run"
          "--machine"
          "-d"
          "android"
          "-d"
          "localhost:5555"
        ];
        manager = "flutter";
      };
    };
  };
}