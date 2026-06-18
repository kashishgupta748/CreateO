//
//  AIFilterService.swift
//  CreateO
//

import Foundation
import UIKit

enum AIFilterError: Error {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case imageConversionFailed
}

actor AIFilterService {
    static let shared = AIFilterService()
    
    // Change this to the IP of the machine if running on a real device.
    // For iOS Simulator, localhost or 127.0.0.1 works.
    private let baseURL = "http://127.0.0.1:3000"
    
    func applyFilter(image: UIImage, filter: Filter) async throws -> UIImage {
        // Map to backend style string
        let styleStr: String
        switch filter {
        case .animeStyle: styleStr = "anime"
        case .watercolor: styleStr = "watercolor"
        case .sketch: styleStr = "sketchbook"
        default:
            throw AIFilterError.apiError("Filter not supported by AI")
        }
        
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw AIFilterError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AIFilterError.imageConversionFailed
        }
        
        var body = Data()
        // Style form field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"style\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(styleStr)\r\n".data(using: .utf8)!)
        
        // Image form field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIFilterError.invalidResponse
        }
        
        struct APIResponse: Decodable {
            let success: Bool?
            let outputImageURL: String?
            let error: String?
        }
        
        let apiRes = try JSONDecoder().decode(APIResponse.self, from: data)
        
        if !(apiRes.success ?? false) || httpResponse.statusCode != 200 {
            throw AIFilterError.apiError(apiRes.error ?? "Unknown backend error")
        }
        
        guard let outputURLStr = apiRes.outputImageURL, let outputURL = URL(string: outputURLStr) else {
            throw AIFilterError.invalidResponse
        }
        
        // Fetch the generated image
        let (imgData, imgResponse) = try await URLSession.shared.data(from: outputURL)
        guard let _ = imgResponse as? HTTPURLResponse, let finalImg = UIImage(data: imgData) else {
            throw AIFilterError.invalidResponse
        }
        
        return finalImg
    }
}
