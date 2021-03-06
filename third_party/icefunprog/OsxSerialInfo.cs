using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using Claunia.PropertyList;

class OsxSerialInfo
{
    private static NSArray getIoReg()
    {
        var startInfo = new ProcessStartInfo () {
            FileName = "sh",
            Arguments = "-c \"ioreg -rlan IOUSBHostInterface\"",
            CreateNoWindow = true,
            RedirectStandardOutput = true
        };
        StringBuilder builder = new StringBuilder();
        using (Process process = Process.Start(startInfo)) {
            builder.Append(process.StandardOutput.ReadToEnd());
            process.WaitForExit();
        }
        return (NSArray) PropertyListParser.Parse(new ASCIIEncoding().GetBytes(builder.ToString()));
    }
    private static bool tryMatchDevice(NSNumber vid, NSNumber pid) {
        return (vid?.ToInt() ?? 0) == 0x04d8 && (pid?.ToInt() ?? 0) == 0xffee;
    }
    private static Tuple<string, string> tryFindIODevice(NSDictionary dev) {
        NSDictionary node = dev;
        NSObject child = null, IOCalloutDevice = null, IODialinDevice = null;
        while(node != null) {
            if(node.TryGetValue("IODialinDevice", out IODialinDevice) &&
                node.TryGetValue("IOCalloutDevice", out IOCalloutDevice))
                break;
            if(!node.TryGetValue("IORegistryEntryChildren", out child))
                break;
            if(child is NSArray)
                node = (child as NSArray)[0] as NSDictionary;
            else
                node = child as NSDictionary;
        }
        return Tuple.Create(
            (IODialinDevice as NSString)?.Content,
            (IOCalloutDevice as NSString)?.Content
        );
    }
    public static void enumerate()
    {
        foreach(var node in getIoReg()) {
            var dev = node as NSDictionary;
            if(dev == null) continue;
            
            // Get device properties
            NSObject a, b, c, d;
            dev.TryGetValue("idVendor", out a);
            dev.TryGetValue("idProduct", out b);
            dev.TryGetValue("USB Product Name", out c);
            dev.TryGetValue("USB Vendor Name", out d);

            // Null checks
            NSNumber idVendor = a as NSNumber;
            NSNumber idProduct = b as NSNumber;
            string vendorName = (c as NSString)?.Content;
            string productName = (d as NSString)?.Content;
            var iodev = tryFindIODevice(dev);
            
            // Let's just skip the unknown products for now...
            if(vendorName == null || productName == null) continue;

            // Try match vendor and product
            bool isDevice = tryMatchDevice(idVendor, idProduct);
            if(isDevice && (iodev.Item1 == null || iodev.Item2 == null)) {
                // Bad product
                continue;
            }
            string isFun = isDevice ? "v" : "x";
            string devid_fmt = iodev.Item1 ?? "??";
                //$"{idVendor?.ToInt().ToString("X") ?? "??"}:{idProduct?.ToInt().ToString("X") ?? "??"}";
            Console.WriteLine($"[{isFun}] {vendorName ?? "Unknown vendor"} {productName ?? "Unknown product"}, tty = {devid_fmt}");
        }
    }
    public static string tryFind()
    {
        foreach(var node in getIoReg()) {
            var dev = node as NSDictionary;
            if(dev == null) continue;
            NSObject idVendor, idProduct;
            dev.TryGetValue("idVendor", out idVendor);
            dev.TryGetValue("idProduct", out idProduct);
            var iodev = tryFindIODevice(dev);
            bool isDevice = tryMatchDevice(idVendor as NSNumber, idProduct as NSNumber);
            if(isDevice && iodev.Item1 != null && iodev.Item2 != null) {
                Console.WriteLine($"Found device at {iodev.Item2}");
                return iodev.Item1;
            }
        }
        return null;
    }
}