export  class Truncate{
  public static string(value: string, maxLength: number): string {
    return value.length > maxLength ? value.substring(0, maxLength) + '...' : value;
  }
}