import SwiftUI
import UIKit

/// UIKit Stage들이 함께 쓰는 시세 행. 모든 Stage가 같은 셀을 써서 UI 비용을 같게 한다.
final class QuoteCell: UITableViewCell {
    static let reuseIdentifier = "QuoteCell"

    private let rankLabel = UILabel()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let priceLabel = UILabel()
    private let rateLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        layout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Layout

    private func layout() {
        rankLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        rankLabel.textColor = .secondaryLabel
        rankLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true
        nameLabel.font = .preferredFont(forTextStyle: .body)
        detailLabel.font = .preferredFont(forTextStyle: .caption1)
        detailLabel.textColor = .secondaryLabel
        priceLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        priceLabel.textAlignment = .right
        rateLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        rateLabel.textAlignment = .right

        let names = UIStackView(arrangedSubviews: [nameLabel, detailLabel])
        names.axis = .vertical
        let prices = UIStackView(arrangedSubviews: [priceLabel, rateLabel])
        prices.axis = .vertical
        prices.alignment = .trailing
        let row = UIStackView(arrangedSubviews: [rankLabel, names, prices])
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            row.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    // MARK: - Configure

    func configure(rank: Int, row: QuoteRow) {
        rankLabel.text = "\(rank + 1)"
        nameLabel.text = row.name
        detailLabel.text = "\(row.symbol) · \(row.sector)"
        priceLabel.text = row.price.formatted(.number.precision(.fractionLength(0)))
        rateLabel.text = row.changeRate.formatted(.percent.precision(.fractionLength(2)).sign(strategy: .always()))
        rateLabel.textColor = UIColor(QuoteStyle.rateColor(row.changeRate))
        flash(row.move)
    }

    /// 바뀐 방향의 색으로 배경을 칠했다가 0.3초 동안 지운다.
    private func flash(_ move: PriceMove) {
        guard let color = QuoteStyle.flashColor(move) else {
            contentView.layer.removeAllAnimations()
            contentView.backgroundColor = .clear
            return
        }
        contentView.backgroundColor = UIColor(color)
        // allowUserInteraction: 애니메이션 중인 뷰도 터치를 받게 한다 (UIView.h). 기본값이면 애니메이션 동안 터치를 무시한다.
        UIView.animate(withDuration: QuoteStyle.flashDuration, delay: 0, options: [.allowUserInteraction]) {
            self.contentView.backgroundColor = .clear
        }
    }
}
