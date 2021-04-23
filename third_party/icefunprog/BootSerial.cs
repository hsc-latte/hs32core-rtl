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
 * @file   BootSerial.cs
 * @author Kevin Dai <kevindai02@outlook.com>
 * @date   Created on March 31 2021, 1:51 AM
 */

using System;
using System.IO;
using System.IO.Ports;
using System.Collections.Generic;
using System.Threading;

class BootSerial
{
    const int len = 16;
    private static byte[] sbuf = new byte[len + 8];
    
    private static void transmit(SerialPort dev, int write_bytes)
    {
        try
        {
            dev.Write(sbuf, 0, write_bytes);
        }
        catch (Exception)
        {

        }
    }

    private static void recieve(SerialPort dev, int read_bytes)
    {
        int x;
        for (x = 0; x < read_bytes; x++)
        {
            try
            {
                dev.Read(sbuf, x, 1);
            }
            catch (Exception)
            {
                sbuf[0] = 255;
            }
        }
    }

    public static void doUpload(SerialPort device, FileInfo file, bool verify)
    {
        if (file == null || !file.Exists)
        {
            Console.WriteLine($"Error: File \"{file.FullName}\" does not exist");
            Environment.Exit(1);
        }

        device.DiscardInBuffer();

        using(FileStream fs = file.OpenRead()) {
            int len = (int) fs.Length;

            // Do the write!
            sbuf[3] = (byte)((len >>  0) & 0xff);
            sbuf[2] = (byte)((len >>  8) & 0xff);
            sbuf[1] = (byte)((len >> 16) & 0xff);
            sbuf[0] = (byte)((len >> 24) & 0xff);
            transmit(device, 4);

            for(int i = 0; i < len; i++) {
                byte b = (byte) fs.ReadByte();
                sbuf[0] = b;
                transmit(device, 1);
            }

            sbuf[0] = sbuf[1] = sbuf[2] = sbuf[3] = 0;
            transmit(device, 4);
            
            if(verify) {
                List<string> diff = new List<string>();

                fs.Seek(0, SeekOrigin.Begin);
                Console.WriteLine("Verifying echoed bytes...");
                for(int i = 0 ; i < len; i++) {
                    if(i != 0 && i % 16 == 0) Console.WriteLine();

                    byte a = (byte) device.ReadByte();
                    byte b = (byte) fs.ReadByte();
                    var fg = Console.ForegroundColor;
                    if(a != b) {
                        Console.ForegroundColor = ConsoleColor.Red;
                        diff.Add(string.Format("[{0:X8}] {1:X2} -> {2:X2}", i, b, a));
                    }
                    Console.Write("{0:X2} ", a);
                    Console.ForegroundColor = fg;
                }
                Console.WriteLine();
                Console.WriteLine("Total byte errors: {0:D}", diff.Count);
                foreach(var s in diff)
                    Console.WriteLine(s);
            }
        }
        
        return;
    }

    public static void doMemtest(SerialPort flash, SerialPort device)
    {
        Console.WriteLine("Beginning tests!");


        sbuf[3] = (byte)((len >>  0) & 0xff);
        sbuf[2] = (byte)((len >>  8) & 0xff);
        sbuf[1] = (byte)((len >> 16) & 0xff);
        sbuf[0] = (byte)((len >> 24) & 0xff);

        for(byte i = 0; i <= 0xFF; i++) {
            flash.DiscardInBuffer();
            
            for(int j = 0; j < len; j++) {
                sbuf[j+4] = i;
            }
            transmit(flash, len + 8);

            bool fail = false;
            for(int j = 0; j < len; j++) {
                byte a = (byte) flash.ReadByte();
                if(a != i) {
                    Console.WriteLine("Test 0x{0:X2} failed. Got 0x{1:X2} instead.", i, a);
                    fail = true;
                    break;
                }
            }
            if(!fail) Console.WriteLine("Test 0x{0:X2} ok.", i);

            IceSerial.resetFpga(device);
            IceSerial.runFpga(device);
            Thread.Sleep(500);
            flash.DiscardInBuffer();
        }
    }
}