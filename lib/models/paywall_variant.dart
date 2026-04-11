enum PaywallVariant {
  emotional,
  loss,
  growth,
}

extension PaywallVariantX on PaywallVariant {
  String get code {
    switch (this) {
      case PaywallVariant.emotional:
        return 'A_emotional';
      case PaywallVariant.loss:
        return 'B_loss';
      case PaywallVariant.growth:
        return 'C_growth';
    }
  }
}
