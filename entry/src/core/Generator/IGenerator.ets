export interface IGenerator {
  compute(counter: number): Promise<string>;
}