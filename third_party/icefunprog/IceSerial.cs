/*
 * Copyright (c) 2021 The HSC Core Authors
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     https://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * 
 * @file   IceSerial.cs
 * @author Kevin Dai <kevindai02@outlook.com>
 * @date   Created on November 29 2076, 3:54 AM
 */

using System;
using System.IO;
using System.IO.Ports;
using System.Runtime.InteropServices;

class IceSerialInfo
{
    public static void enumerate()
    {
        Console.WriteLine("Legend: [?] Unknown Device, [x] Not IceWerx, [v] IceWerx");
        if(RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            Win32SerialInfo.enumerate();
        else if(RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
            OsxSerialInfo.enumerate();
        else if(RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            LinuxSerialInfo.enumerate();
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
        else if(RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            return LinuxSerialInfo.tryFind();
        else {
            Console.WriteLine("Platform not supported.");
        }
        return null;
    }
}

class IceSerial
{
    enum cmds
    {
        DONE = 0xB0, GET_VER, RESET_FPGA, ERASE_CHIP, ERASE_64k, PROG_PAGE, READ_PAGE, VERIFY_PAGE, GET_CDONE, RELEASE_FPGA
    };

    const Int32 PROGSIZE = 1048576;
    private static byte[] sbuf = new byte[300];
    
    private static void transmit(SerialPort dev, int write_bytes)
    {
        try
        {
            dev.Write(sbuf, 0, write_bytes);      // writes specified amount of sbuf out on COM port
        }
        catch (Exception)
        {

        }
    }

    private static void recieve(SerialPort dev, int read_bytes)
    {
        int x;
        for (x = 0; x < read_bytes; x++)    // this will call the read function for the passed number times, 
        {                                   // this way it ensures each byte has been correctly recieved while
            try                             // still using timeouts
            {
                dev.Read(sbuf, x, 1);     // retrieves 1 byte at a time and places in sbuf at position x
            }
            catch (Exception)               // timeout or other error occured, set lost comms indicator
            {
                sbuf[0] = 255;
            }
        }
    }

    // Verify the file already loaded in pbuf
    private static bool doVerify(SerialPort device, byte[] pbuf, int len)
    {
        int addr = 0;
        Console.Write("Verifying ");
        int cnt = 0;
        while (addr < len)
        {
            sbuf[0] = (byte)cmds.VERIFY_PAGE;
            sbuf[1] = (byte)(addr >> 16);
            sbuf[2] = (byte)(addr >> 8);
            sbuf[3] = (byte)addr;
            for (int x = 0; x < 256; x++) sbuf[x + 4] = pbuf[addr++];
            transmit(device, 260);
            recieve(device, 4);
            if (sbuf[0] > 0)
            {
                Console.WriteLine();
                Console.WriteLine("Verify failed at {0:X06}, {1:X02} expected, {2:X02} read.", addr - 256 + sbuf[1] - 4, sbuf[2], sbuf[3]);
                return false;
            }
            if (++cnt == 10)
            {
                cnt = 0;
                Console.Write(".");
            }
        }
        Console.WriteLine();
        Console.WriteLine("Verify Success!");
        return true;
    }

    public static void resetFpga(SerialPort device)
    {
        sbuf[0] = (byte)cmds.RESET_FPGA;
        transmit(device, 1);
        recieve(device, 3);
        Console.WriteLine("FPGA reset.");
        Console.WriteLine("Flash ID = {0:X02} {1:X02} {2:X02}", sbuf[0], sbuf[1], sbuf[2]);
    }

    public static void runFpga(SerialPort device)
    {
        sbuf[0] = (byte)cmds.RELEASE_FPGA;
        transmit(device, 1);
        recieve(device, 1);
    }

    public static void getVersion(SerialPort device)
    {
        sbuf[0] = (byte) IceSerial.cmds.GET_VER;
        transmit(device, 1);
        recieve(device, 2);
        if (sbuf[0] == 38) Console.WriteLine("Device Info: iceFUN Programmer, V{0}", sbuf[1]);
    }

    public static void doUpload(SerialPort device, FileInfo file, bool verify)
    {
        if (file == null || !file.Exists)
        {
            Console.WriteLine($"Error: File \"{file.FullName}\" does not exist");
            Environment.Exit(1);
        }

        byte[] pbuf = new byte[PROGSIZE];
        FileStream fs = file.OpenRead();
        for (int i = 0; i < PROGSIZE; i++) pbuf[i] = 0xff;
        resetFpga(device);
        int len = (int)fs.Length;
        Console.WriteLine("Program length 0x{0:X06}", len);
        fs.Read(pbuf, 0, len);
        int erasePages = (len >> 16) + 1;
        for (int page = 0; page < erasePages; page++)
        {
            sbuf[0] = (byte)cmds.ERASE_64k;
            sbuf[1] = (byte)page;
            transmit(device, 2);
            Console.WriteLine("Erasing sector 0x{0:X02}0000", page);
            recieve(device, 1);
        }
        int addr = 0;
        Console.Write("Programming ");
        int cnt = 0;
        while (addr < len)
        {
            sbuf[0] = (byte)cmds.PROG_PAGE;
            sbuf[1] = (byte)(addr >> 16);
            sbuf[2] = (byte)(addr >> 8);
            sbuf[3] = (byte)addr;
            for (int x = 0; x < 256; x++) sbuf[x + 4] = pbuf[addr++];
            transmit(device, 260);
            recieve(device, 4);
            if (sbuf[0] != 0)
            {
                Console.WriteLine();
                Console.WriteLine("Program failed at {0:X06}, {1:X02} expected, {2:X02} read.", addr - 256 + sbuf[1] - 4, sbuf[2], sbuf[3]);
                fs.Close();
                Environment.Exit(1);
            }
            if (++cnt == 10)
            {
                cnt = 0;
                Console.Write(".");
            }
        }
        if (sbuf[0] == 0)
        {
            if (verify)
            {
                doVerify(device, pbuf, len);
            }
            runFpga(device);
            Console.WriteLine("Done.");
        }
        fs.Close();
    }
}