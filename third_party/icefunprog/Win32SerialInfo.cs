using System;
using System.IO.Ports;
using System.Linq;
using System.Management;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;

class Win32SerialInfo
{
    const string WIN32_DEVID_REGEX = @"VID_([0-9a-fA-F]{4})&PID_([0-9a-fA-F]{4})";
    const string WIN32_DEV_QUERY = "SELECT * FROM WIN32_SerialPort";
    private static bool tryMatchDevice(string vid, string pid) {
        return vid == "04d8" && pid == "ffee";
    }
    public static void enumerate()
    {
        using (var search = new ManagementObjectSearcher(WIN32_DEV_QUERY))
        {
            var devices = search.Get().Cast<ManagementBaseObject>().ToList();
            devices.ForEach(x =>
            {
                // x.Properties["DeviceID"].Value
                string devid = (string) x.Properties["PNPDeviceID"].Value;
                string devid_fmt = $"Invalid ID ({devid})";
                string isFun = "?";
                var mc = Regex.Match(devid, WIN32_DEVID_REGEX).Groups;
                if(mc.Count == 3) {
                    devid_fmt = $"{mc[1].Value}:{mc[2].Value} ({devid})";
                    isFun = tryMatchDevice(mc[1].Value.ToLower(), mc[2].Value.ToLower()) ? "v" : "x";
                }
                Console.WriteLine($"[{isFun}] {x.Properties["Name"].Value}, ID = {devid_fmt}");
            });
        }
    }
    public static string tryFind()
    {
        using (var search = new ManagementObjectSearcher(WIN32_DEV_QUERY))
        {
            var devices = search.Get().Cast<ManagementBaseObject>().ToList();
            foreach(var x in devices)
            {
                var mc = Regex.Match(
                    (string) x.Properties["PNPDeviceID"].Value, WIN32_DEVID_REGEX).Groups;
                if(mc.Count == 3 && tryMatchDevice(mc[1].Value.ToLower(), mc[2].Value.ToLower())) {
                    Console.WriteLine($"Found device at {x.Properties["Name"].Value}");
                    return (string) x.Properties["DeviceID"].Value;
                }
            }
        }
        return null;
    }
}