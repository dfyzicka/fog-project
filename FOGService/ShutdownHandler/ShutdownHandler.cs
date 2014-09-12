﻿
using System;
using System.IO;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;

using FOG;

namespace FOG {
	/// <summary>
	/// Handle all shutdown requests
	/// The windows shutdown command is used instead of the win32 api because it notifies the user prior
	/// </summary>
	public static class ShutdownHandler {

		//Define variables
		private static Boolean shutdownPending = false;
		private static Boolean updatePending = false;
		private const String LOG_NAME = "ShutdownHandler";
		
		//Load the ability to lock the computer from the native user32 dll
		[DllImport("user32")]
		private static extern void LockWorkStation();
		
		//List all possible shutdown types
		public enum ShutDownType {
			LogOff = 0,
			Shutdown = 1,
			Reboot = 2,
			ForcedLogOff = 4,
			ForcedShutdown = 5,
			ForcedReboot = 6,
			PowerOff = 8,
			ForcedPowerOff = 12
		}
		
		//List options on how to exit windows
		[Flags]
		public enum ExitWindows : uint
		{
			LogOff = 0x00,
			ShutDown = 0x01,
			Reboot = 0x02,
			PowerOff = 0x08,
			RestartApps = 0x40,
			Force = 0x04,
			ForceIfHung = 0x10,
		}
		
		//Check if a shutdown was requested
		public static Boolean isShutdownPending() { return shutdownPending; }
		
		private static void createShutdownCommand(String parameters) {
			LogHandler.log(LOG_NAME, "Creating shutdown request");
			LogHandler.log(LOG_NAME, "Parameters: " + parameters);

			Process.Start("shutdown", parameters);
		}
		
		public static void shutdown(String comment, int seconds) {
			setShutdownPending(true);
			createShutdownCommand("/s /c \"" + comment + "\" /t " + seconds);
		}
		
		public static void restart(String comment, int seconds) {
			setShutdownPending(true);
			createShutdownCommand("/r /c \"" + comment + "\" /t " + seconds);
		}		
		
		public static void logOffUser() {
			createShutdownCommand("/l");
		}
		
		public static void hibernate(String comment, int seconds) {
			createShutdownCommand("/h" );
		}
		
		public static void lockWorkStation() {			
			LockWorkStation();
		}
		
		public static void abortShutdown() {		
			setShutdownPending(false);
			createShutdownCommand("/a");
		}
		
		private static void setShutdownPending(Boolean sPending) {
			shutdownPending = sPending;
		}
		
		//Treat this like a shutdown request because it should halt the service
		public static void restartService() {
			LogHandler.log(LOG_NAME, "Restarting service");
			setShutdownPending(true);
			Process process = new Process();
			process.StartInfo.UseShellExecute = false;
			process.StartInfo.FileName = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location) + @"\RestartFOGService.exe";
			process.Start();
		}
		
		public static void scheduleUpdate() {
			updatePending = true;
		}

		public static Boolean isUpdatePending() {
			return updatePending;
		}
		
		public static void unScheduleUpdate() {
			updatePending = false;
		}
		
		//Spawn an UpdateWaiter with the fileName parameter
		public static void spawnUpdateWaiter(String fileName) {
			LogHandler.log(LOG_NAME, "Spawning update waiter");
			
			Process process = new Process();
			process.StartInfo.UseShellExecute = false;
			process.StartInfo.FileName = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location) + @"\FOGUpdateWaiter.exe";
			process.StartInfo.Arguments = "\"" + fileName + "\"";
			
			LogHandler.log(LOG_NAME, "Update Waiter args");
			LogHandler.log(LOG_NAME, process.StartInfo.FileName + " " + process.StartInfo.Arguments);
			process.Start();			
		}
	}
}