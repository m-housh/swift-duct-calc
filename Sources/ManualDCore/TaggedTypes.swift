import Tagged

/// A name space for general tag types.
public enum Tag {
  public enum CFM {}
  public enum DesignFrictionRate {}
  public enum Height {}
  public enum Round {}
  public enum Width {}
}

public typealias CFM = Tagged<Tag.CFM, Int>
public typealias DesignFrictionRate = Tagged<Tag.DesignFrictionRate, Double>
public typealias Height = Tagged<Tag.Height, Int>
public typealias RoundSize = Tagged<Tag.Round, Int>
public typealias Width = Tagged<Tag.Width, Int>
