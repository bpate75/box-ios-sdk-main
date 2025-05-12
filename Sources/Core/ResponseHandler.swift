//
//  ResponseHandler.swift
//  BoxSDK-iOS
//
//  Created by Matthew Willer on 8/1/19.
//  Copyright © 2019 box. All rights reserved.
//

import Foundation
import OSLog
/// Utility methods for common response handling
public enum ResponseHandler {

    /// Make sure the response is successful (status code 2xx) and deserialize
    /// the response body into the appropriate type.
    ///
    /// - Parameter completion: The user-specified completion block to call with the resulting deserialized object
    public static func `default`<T: BoxModel>(wrapping completion: @escaping Callback<T>) -> Callback<BoxResponse> {
        return { (result: Result<BoxResponse, BoxSDKError>) in
            let objectResult: Result<T, BoxSDKError> = result.flatMap { ObjectDeserializer.deserialize(data: $0.body) }
            completion(objectResult)
        }
    }
    
    public static func customTokenResponseHandler<T: Decodable>(wrapping completion: @escaping Callback<T>) -> Callback<BoxResponse> {
        return { (result: Result<BoxResponse, BoxSDKError>) in
            // Log the raw response for debugging
            if case .success(let response) = result, let data = response.body {
                if #available(iOS 14.0, *) {
                    os_log("Raw response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode as string")")
                } else {
                    // Fallback on earlier versions
                }
            }
            
            // Try to deserialize with additional error handling
            let objectResult: Result<T, BoxSDKError> = result.flatMap { response in
                do {
                    return try ObjectDeserializer.deserialize(response: response)
                } catch let error as BoxSDKError {
                    return .failure(error)
                } catch {
                    // Convert any other errors to BoxSDKError
                    return .failure(BoxSDKError(message: .customValue("Deserialization error: \(error.localizedDescription)")))
                }
            }
            
            // Ensure completion is called on main thread
            DispatchQueue.main.async {
                completion(objectResult)
            }
        }
    }



    /// Make sure the response is successful (status code 2xx) and deserialize
    /// the response body into the appropriate type.
    ///
    /// - Parameter completion: The user-specified completion block to call with the resulting deserialized object
    public static func `default`<T: Decodable>(wrapping completion: @escaping Callback<T>) -> Callback<BoxResponse> {
        return { (result: Result<BoxResponse, BoxSDKError>) in
            let objectResult: Result<T, BoxSDKError> = result.flatMap { ObjectDeserializer.deserialize(response: $0) }
            completion(objectResult)
        }
    }

    /// Ensure the response was successful (status code 2xx) and transform to void result,
    /// for operations that do not return meaningful results — just success vs. failure.
    ///
    /// - Parameter completion: The user-specified completion block to call with the result
    public static func `default`(wrapping completion: @escaping Callback<Void>) -> Callback<BoxResponse> {
        return { (result: Result<BoxResponse, BoxSDKError>) in
            let objectResult = result.map { _ in }
            completion(objectResult)
        }
    }

    /// This will help the user unwrap a response object that comes back as a collection where the collection
    /// is only of size one. This will give the user an Entry Container containing the Box Model expected.
    /// - Parameter completion: The user-specified completion block to call with the result
    public static func unwrapCollection<T: BoxModel>(wrapping completion: @escaping Callback<T>) -> Callback<BoxResponse> {
        return { result in
            completion(result.flatMap {
                ObjectDeserializer.deserialize(data: $0.body).flatMap { (container: EntryContainer<T>) in
                    guard let entry = container.entries.first else {
                        return Result.failure(BoxCodingError(message: .typeMismatch(key: "entries")))
                    }
                    return Result.success(entry)
                }
            })
        }
    }
}
