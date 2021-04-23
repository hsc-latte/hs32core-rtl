using System;
using System.Diagnostics;
using System.Text;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.IO;

class LinuxSerialInfo
{
    static readonly Regex regex = new Regex("(.*)='(.*)'");
    private static string runBashCommand(string cmd) {
        var startInfo = new ProcessStartInfo () {
            FileName = "bash",
            Arguments = $"-c \"{cmd}\"",
            CreateNoWindow = true,
            RedirectStandardOutput = true
        };
        StringBuilder builder = new StringBuilder();
        using (Process process = Process.Start(startInfo)) {
            builder.Append(process.StandardOutput.ReadToEnd());
            process.WaitForExit();
        }
        return builder.ToString();
    }
    private static Dictionary<string, string> parseUdevadm(string[] lines) {
        Dictionary<string, string> dict = new Dictionary<string, string>();
        foreach(var s in lines) {
            var m = regex.Match(s);
            if(m == null) continue;
            if(m.Groups.Count == 3)
                dict[m.Groups[1].Value] = m.Groups[2].Value;
        }
        return dict;
    }
    private static bool tryMatchDevice(string vid, string pid) {
        return vid == "04d8" && pid == "ffee";
    }
    public static void enumerate()
    {
        var devices = runBashCommand("find /sys/bus/usb/devices/usb*/ -name dev").Split("\n");
        foreach(var d in devices) {
            if(String.IsNullOrWhiteSpace(d)) continue;

            var devpath = Directory.GetParent(d).ToString();
            var devname = runBashCommand($"udevadm info -q name --export -p {devpath}");
            var devinfo = runBashCommand($"udevadm info -q property --export -p {devpath}");
            var udev = parseUdevadm(devinfo.Split("\n"));

            if(devname.Contains("bus/")) continue;
            if( !udev.ContainsKey("ID_BUS") ||
                !udev.ContainsKey("ID_VENDOR_ID") ||
                !udev.ContainsKey("ID_MODEL_ID") ||
                !udev.ContainsKey("ID_VENDOR") ||
                !udev.ContainsKey("DEVNAME")) continue;
            if(udev["ID_BUS"] != "usb") continue;

            var vid = udev["ID_VENDOR_ID"].ToLowerInvariant();
            var pid = udev["ID_MODEL_ID"].ToLowerInvariant();
            var desc = udev["ID_VENDOR"];
            var path = udev["DEVNAME"];
            var isFun = tryMatchDevice(vid, pid) ? "v" : "x";

            Console.WriteLine($"[{isFun}] dev = {vid}/{pid}, desc = {desc} ({path})");
        }
    }
    public static string tryFind()
    {
        var devices = runBashCommand("find /sys/bus/usb/devices/usb*/ -name dev").Split("\n");
        foreach(var d in devices) {
            if(String.IsNullOrWhiteSpace(d)) continue;

            var devpath = Directory.GetParent(d).ToString();
            var devname = runBashCommand($"udevadm info -q name --export -p {devpath}");
            var devinfo = runBashCommand($"udevadm info -q property --export -p {devpath}");
            var udev = parseUdevadm(devinfo.Split("\n"));

            if(devname.Contains("bus/")) continue;
            if( !udev.ContainsKey("ID_BUS") ||
                !udev.ContainsKey("ID_VENDOR_ID") ||
                !udev.ContainsKey("ID_MODEL_ID") ||
                !udev.ContainsKey("DEVNAME")) continue;
            if(udev["ID_BUS"] != "usb") continue;

            var vid = udev["ID_VENDOR_ID"].ToLowerInvariant();
            var pid = udev["ID_MODEL_ID"].ToLowerInvariant();
            var path = udev["DEVNAME"];
            if(tryMatchDevice(vid, pid))
                return path;
        }

        return null;
    }
}
