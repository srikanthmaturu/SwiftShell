/*
* Released under the MIT License (MIT), http://opensource.org/licenses/MIT
*
* Copyright (c) 2015 Kåre Morstøl, NotTooBad Software (nottoobadsoftware.com)
*
*/

import Foundation

public protocol ShellContextType: CustomDebugStringConvertible {
	var encoding: String.Encoding {get set}
	var env: [String: String] {get set}

	var stdin: ReadableStream {get set}
	var stdout: WritableStream {get set}
	var stderror: WritableStream {get set}

	/**
	The current working directory.

	Must be used instead of `run("cd", "...")` because all the `run` commands are executed in a
	separate process and changing the directory there will not affect the rest of the Swift script.
	*/
	var currentdirectory: String {get set}
}

extension ShellContextType {
	/** A textual representation of this instance, suitable for debugging. */
	public var debugDescription: String {
		var result = ""
		debugPrint("encoding:", encoding, "stdin:", stdin, "stdout:", stdout, "stderror:", stderror, "currentdirectory:", currentdirectory, to: &result)
		debugPrint("env:", env, to: &result)
		return result
	}
}

public struct ShellContext: ShellContextType {
	public var encoding: String.Encoding
	public var env: [String: String]

	public var stdin: ReadableStream
	public var stdout: WritableStream
	public var stderror: WritableStream

	/**
	The current working directory.

	Must be used instead of `run("cd", "...")` because all the `run` commands are executed in a
	separate process and changing the directory there will not affect the rest of the Swift script.
	*/
	public var currentdirectory: String

	/** Creates a blank ShellContext. */
	public init () {
		encoding = String.Encoding.utf8
		env = [String:String]()

		stdin =    FileHandleStream(FileHandle.nullDev, encoding: encoding)
		stdout =   FileHandleStream(FileHandle.nullDev, encoding: encoding)
		stderror = FileHandleStream(FileHandle.nullDev, encoding: encoding)

		currentdirectory = main.currentdirectory
	}

	/** Creates a new ShellContext from another ShellContextType. */
	public init (_ context: ShellContextType) {
		encoding = context.encoding
		env = context.env

		stdin =    context.stdin
		stdout =   context.stdout
		stderror = context.stderror

		currentdirectory = context.currentdirectory
	}
}

extension ShellContext: ShellRunnable {
	public var shellcontext: ShellContextType { return self }
}


private func createTempdirectory () -> String {
	let name = URL(fileURLWithPath: main.path).lastPathComponent
	let tempdirectory = URL(fileURLWithPath:NSTemporaryDirectory()) + (name + "-" + ProcessInfo.processInfo.globallyUniqueString)
	do {
		try Files.createDirectory(atPath: tempdirectory.path, withIntermediateDirectories: true, attributes: nil)
		return tempdirectory.path + "/"
	} catch let error as NSError {
		exit(errormessage: "Could not create new temporary directory '\(tempdirectory)':\n\(error.localizedDescription)", errorcode: error.code)
	} catch {
		exit(errormessage: "Unexpected error: \(error)")
	}
}

extension CommandLine {

	/** Workaround for nil crash in CommandLine.arguments when run in Xcode. */
	static var safeArguments: [String] {
		return self.argc == 0 ? [] : self.arguments
	}
}

public final class MainShellContext: ShellContextType {

	/** 
	The default character encoding for SwiftShell.

	TODO: get encoding from environmental variable LC_CTYPE.
	*/
	public var encoding = String.Encoding.utf8
	public lazy var env = ProcessInfo.processInfo.environment as [String: String]

	public lazy var stdin: ReadableStream = { FileHandleStream(FileHandle.standardInput, encoding: self.encoding) }()
	public lazy var stdout: WritableStream = { StdoutStream.default }()
	public lazy var stderror: WritableStream = { FileHandleStream(FileHandle.standardError, encoding: self.encoding) }()

	/**
	The current working directory.

	Must be used instead of `run("cd", "...")` because all the `run` commands are executed in
	separate processes and changing the directory there will not affect the rest of the Swift script.

	This directory is also used as the base for relative URLs.
	*/
	public var currentdirectory: String {
		get {	return Files.currentDirectoryPath + "/" }
		set {
			if !Files.changeCurrentDirectoryPath(newValue) {
				exit(errormessage: "Could not change the working directory to \(newValue)")
			}
		}
	}

	/**
	The tempdirectory is unique each time a script is run and is created the first time it is used.
	It lies in the user's temporary directory and will be automatically deleted at some point.
	*/
	public lazy var tempdirectory: String = createTempdirectory()

	/** The arguments this executable was launched with. Use main.path to get the path. */
	public lazy var arguments: [String] = Array(CommandLine.safeArguments.dropFirst())

	/** The path to the currently running executable. Will be empty in playgrounds. */
	public lazy var path: String = CommandLine.safeArguments.first ?? ""

	fileprivate init() {
	}
}

extension MainShellContext: ShellRunnable {
	public var shellcontext: ShellContextType { return self }
}

public let main = MainShellContext()
