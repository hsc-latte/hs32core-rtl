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
 * @file   Program.cs
 * @author Kevin Dai <kevindai02@outlook.com>
 * @date   Created on November 29 2076, 3:54 AM
 */

// Original source for GUI programmer can be found
// here https://www.robot-electronics.co.uk/files/iceWerx.pdf

using System;
using System.IO;
using System.IO.Ports;
using System.CommandLine;
using System.CommandLine.Invocation;
using System.Threading;

class Program
{
    static void Main(string[] args)
    {
        var argport = new Option<string>(
            aliases: new string[] { "--port", "-p" },
            description: "Set device name (can be null)",
            getDefaultValue: () =>
            {
                return null;
            });
        var argfile = new Argument<FileInfo>(
            name: "file",
            description: "Binary file to upload",
            getDefaultValue: () => null);
        var argverify = new Option<bool>(
            aliases: new string[] { "--verify", "-v" },
            description: "Verify after upload");
        var argtty = new Option<bool>(
            aliases: new string[] { "--tty", "-i" },
            description: "Enter tty mode after flashing");
        var cmdlist = new Command("list", "Enumerate serial port devices");
        var cmdrun = new Command("run", "Run the FPGA device");
        cmdrun.AddOption(argport);
        var cmdreset = new Command("reset", "Reset (not erase) the FPGA device");
        cmdreset.AddOption(argport);
        var cmdprogram = new Command("program", "Upload binary bitstream to the FPGA");
        cmdprogram.AddOption(argport);
        cmdprogram.AddOption(argverify);
        cmdprogram.AddArgument(argfile);
        var cmdflashboot = new Command("flash", "Upload program to bootstrap using the serial port of the uploader");
        cmdflashboot.AddOption(argport);
        cmdflashboot.AddOption(argverify);
        cmdflashboot.AddOption(argtty);
        cmdflashboot.AddArgument(argfile);
        var cmdmemtest = new Command("memtest", "Runs the UART memtest");
        cmdmemtest.AddOption(argport);
        var root = new RootCommand { cmdlist, cmdrun, cmdreset, cmdprogram, cmdflashboot, cmdmemtest };
        cmdlist.Handler = CommandHandler.Create<string, FileInfo>(
            (port, file) => {
                IceSerialInfo.enumerate();
            });
        cmdrun.Handler = CommandHandler.Create<string>(
            (port) => {
                var device = tryGetICEDevice(port == null ? IceSerialInfo.tryFindDevicePort() : port);
                IceSerial.runFpga(device);
                Console.WriteLine("Running...");
            });
        cmdreset.Handler = CommandHandler.Create<string>(
            (port) => {
                var device = tryGetICEDevice(port == null ? IceSerialInfo.tryFindDevicePort() : port);
                IceSerial.resetFpga(device);
                Console.WriteLine("Done.");
            });
        cmdprogram.Handler = CommandHandler.Create<bool, string, FileInfo>(
            (verify, port, file) => {
                var device = tryGetICEDevice(port == null ? IceSerialInfo.tryFindDevicePort() : port);
                IceSerial.doUpload(device, file, verify);
            });
        cmdflashboot.Handler = CommandHandler.Create<bool, string, FileInfo, bool>(
            (verify, port, file, tty) => {
                var (flash, device) = tryGetSerialFlasher(port);
                BootSerial.doUpload(flash, file, verify);
                if(tty) enterTtyMode(flash);
                flash.Close();
                device.Close();
            });
        cmdmemtest.Handler = CommandHandler.Create<string>(
            (port) => {
                var (flash, device) = tryGetSerialFlasher(port);
                BootSerial.doMemtest(flash, device);
                flash.Close();
                device.Close();
            });
        root.Invoke(args);
        Environment.Exit(0);
    }

    static SerialPort tryGetICEDevice(string foundPort)
    {
        if (foundPort == null)
        {
            Console.WriteLine($"Error: IceWerx device not found.");
            Environment.Exit(1);
        }

        // Flash
        SerialPort device = new SerialPort(
            portName: foundPort,
            parity: Parity.None,
            baudRate: 19200,
            stopBits: StopBits.Two,
            dataBits: 8
        );
        tryWakeGenericDevice(device);
        IceSerial.getVersion(device);
        return device;
    }

    static (SerialPort, SerialPort) tryGetSerialFlasher(string port)
    {
        if(port == null) {
            Console.WriteLine("Port cannot be null here!");
            Environment.Exit(1);
        }
         SerialPort flash = new SerialPort(
            portName: port,
            parity: Parity.None,
            baudRate: 9600,
            stopBits: StopBits.One,
            dataBits: 8
        );
        tryWakeGenericDevice(flash);

        // Reset
        var device = tryGetICEDevice(IceSerialInfo.tryFindDevicePort());
                
        // Wait for serial ports to reset
        Thread.Sleep(2000);
        Console.WriteLine("Resetting serial devices...");

        // Reset FPGA
        IceSerial.resetFpga(device);
        IceSerial.runFpga(device);

        // Simply wait
        Console.WriteLine("Waiting for CPU to wake...");
        Thread.Sleep(500);
        
        return (flash, device);
    }

    static void tryWakeGenericDevice(SerialPort device)
    {
        device.ReadTimeout = 5000;
        device.WriteTimeout = 5000;
        try
        {
            device.Open();
            device.DiscardInBuffer();
        }
        catch (Exception e)
        {   // Hide some errors.
            Console.WriteLine($"USB device failed to open: {e.Message}");
            Environment.Exit(1);
        }
    }

    static void enterTtyMode(SerialPort device)
    {
        // TODO: Add some more options?
        
        Console.WriteLine("Entering tty mode!");
        /*device.DataReceived += new SerialDataReceivedEventHandler((sender, e) => {
            Console.WriteLine(device.ReadExisting());
        });*/
        while(true) {
            Console.Write("> ");

            /*Console.ReadLine();
            device.Write(new byte[] { 0xFF, 0xFF, 0xFF, 0xFF, 0x0D, 0x0A }, 0, 6);
            while(device.BytesToRead > 0) {
                Console.Write("{0:X2} ", device.ReadByte());
            }
            Console.WriteLine();*/

            device.WriteLine(Console.ReadLine());
            Console.WriteLine(device.ReadLine());
        }
    }
}
