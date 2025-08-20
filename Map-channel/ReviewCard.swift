//
//  ReviewCard.swift
//  Map-channel
//
//  Created by user on 2025/08/20.
//

import SwiftUI
import Foundation

// MARK: - Reviews（簡易モデル & UI）
struct Review: Identifiable {
    let id = UUID()
    let author: String
    let rating: Int
    let text: String
    let timestamp: Date?
}

struct ReviewCard: View {
    let review: Review
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "person.circle.fill")
                Text(review.author.isEmpty ? "匿名" : review.author)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            
            if review.rating > 0 {
                StarsView(rating: review.rating)
            }
            
            Text(review.text)
                .font(.body)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: 220, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(UIColor.separator), lineWidth: 0.5)
        )
    }
}

struct StarsView: View {
    let rating: Int
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < rating ? "star.fill" : "star")
            }
        }
        .imageScale(.small)
        .foregroundStyle(.yellow)
        .accessibilityLabel("評価 \(rating) / 5")
    }
}
