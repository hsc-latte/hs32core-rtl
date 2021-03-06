using System;
using System.IO.Ports;
using System.Linq;
using System.Management;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;

class IceSerialInfo
{
    public static void enumerate()
    {
        Console.WriteLine("Legend: [?] Unknown Device, [x] Not IceWerx, [v] IceWerx");
        if(RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            Win32SerialInfo.enumerate();
        else if(RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
            OsxSerialInfo.enumerate();
        else {
            Console.WriteLine("Platform not supported.");
            foreach(var s in SerialPort.GetPortNames()) {
                Console.WriteLine(s);
            }
        }
    }
    public static string tryFindDevicePort()
    {
        Console.WriteLine("No port specified. Attempting to find device 04D8:FFEE (IceWerx)...");
        if(RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            return Win32SerialInfo.tryFind();
        else if(RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
            return OsxSerialInfo.tryFind();
        else {
            Console.WriteLine("Platform not supported.");
        }
        return null;
    }
}