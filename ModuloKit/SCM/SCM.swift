//
//  SCM.swift
//  ModuloKit
//
//  Created by Brandon Sneed on 6/17/16.
//  Copyright © 2016 TheHolyGrail. All rights reserved.
//

import Foundation
#if NOFRAMEWORKS
#else
    import ELCLI
    import ELFoundation
#endif

public typealias SCMCommandParser = (_ status: Int32, _ output: String?) -> Void

public enum SCMResult {
    case success
    case error(code: Int32, message: String)
    
    func errorMessage() -> String {
        switch self {
        case .error(let code, let message) :
            return "\(message), (code \(code))"
        default:
            return ""
        }
    }
    
    func errorCode() -> Int32 {
        switch self {
        case .error(let code, _) :
            return code
        default:
            return 0
        }
    }
}

extension SCMResult: Equatable {}

public func == (left: SCMResult, right: SCMResult) -> Bool {
    switch left {
    case .success:
        switch right {
        case .success:
            return true
        default:
            return false
        }
        
    case .error(let leftCode, let leftMessage):
        switch right {
        case .error(let rightCode, let rightMessage):
            return leftMessage == rightMessage && leftCode == rightCode
        default:
            return false
        }
    }
}

public enum SCMCheckoutType {
    case branch(name: String)
    case tag(name: String)
    case commit(hash: String)
    case other(value: String)
    
    func value() -> String {
        var result: String
        switch self {
        case .branch(let name):
            result = name
            break
        case .tag(let name):
            result = name
            break
        case .commit(let hash):
            result = hash
            break
        case .other(let value):
            result = value
            break
        }
        return result
    }
}


public protocol SCM {
    var verbose: Bool { get set }
    var isInstalled: Bool { get }
    var isInitialized: Bool { get }
    var defaultCheckout: String { get }
    
    func remoteURL() -> String?
    func nameFromRemoteURL(_ url: String) -> String
    func branchName(_ path: String) -> String?
    func clone(_ url: String, path: String) -> SCMResult
    func fetch(_ path: String) -> SCMResult
    func checkout(_ type: SCMCheckoutType, path: String) -> SCMResult
    func remove(_ path: String) -> SCMResult
    func addModulesIgnore() -> SCMResult
    func checkStatus(_ path: String, assumedCheckout: String?) -> SCMResult
    func branches(_ path: String) -> [String]
    func tags(_ path: String) -> [String]
}

extension SCM {
    /*fileprivate func shell(_ command: String) -> (status: Int32, output: String?, error: String?) {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.launch()
        task.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = NSString(data: outputData, encoding: String.Encoding.utf8.rawValue) as? String
        
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let error = NSString(data: errorData, encoding: String.Encoding.utf8.rawValue) as? String
        
        let status = task.terminationStatus
        return (status, output, error)
    }

    @discardableResult
    public func runCommand(_ command: String, completion: SCMCommandParser? = nil) -> Int32 {
        if verbose {
            writeln(.stdout, "Running command: \(command)")
        }
        
        let result = shell(command)
        
        if let completion = completion {
            let output = result.output
            let error = result.error
            let status = result.status
            completion(status, output, error)
            if status != 0 {
                if let output = output {
                    writeln(.stderr, output)
                }
                if let error = error {
                    writeln(.stderr, error)
                }
            }
        }
        
        return result.status
    }*/
    
    @discardableResult
    public func runCommand(_ command: String, silence: Bool = false, completion: SCMCommandParser? = nil) -> Int32 {
        var execute = command
        
        if verbose {
            writeln(.stdout, "Running command: \(command)")
        }
        
        let tempFile = FileManager.temporaryFile()
        
        if completion != nil {
            execute = "\(execute) &> \(tempFile)"
        }
        
        let status = Int32(modulo_system(execute))
        
        if let completion = completion {
            let output = try? String(contentsOfFile: tempFile)
            
            completion(status, output)
            if status != 0 && silence == false, let output = output {
                writeln(.stderr, output)
            }
        }
        
        return status
    }
    
    @discardableResult
    public func remove(_ path: String) -> SCMResult {
        let result = runCommand("rm -rf \(path)")
        if result == 0 {
            return SCMResult.success
        } else {
            return SCMResult.error(code: result, message: "Unable to remove \(path).  Check your permissions.")
        }
    }
    
}

public func currentSCM() -> SCM {
    let scmList = [Git()/*, Mercurial()*/]
    
    var result: SCM? = nil
    for scm in scmList {
        let installed = scm.isInstalled
        let initialized = scm.isInitialized
        
        if installed && initialized {
            result = scm
            break
        }
    }
    
    if result == nil {
        exit(.noSCMFoundOrInitialized)
    }
    
    return result!
}

