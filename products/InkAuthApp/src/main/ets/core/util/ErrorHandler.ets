// ErrorHandler.ets

export class ErrorHandler {
  private static instance: ErrorHandler;
  private errorListeners: Array<(error: Error, context?: string) => void> = [];

  private constructor() {}

  public static getInstance(): ErrorHandler {
    if (!ErrorHandler.instance) {
      ErrorHandler.instance = new ErrorHandler();
    }
    return ErrorHandler.instance;
  }

  public handleError(error: Error, context: string = 'Unknown'): void {
    console.error(`[ErrorHandler] ${context}:`, error);
    this.logError(error, context);

    this.errorListeners.forEach(listener => {
      try {
        listener(error, context);
      } catch (listenerError) {
        console.error('Error in error listener:', listenerError);
      }
    });
  }

  public logError(error: Error, context: string = 'Unknown'): void {
    const timestamp = new Date().toISOString();
    const errorMessage = error.message || 'No error message';
    const errorStack = error.stack || 'No stack trace';

    console.error(`[${timestamp}] Error in ${context}:`);
    console.error(`Message: ${errorMessage}`);
    console.error(`Stack: ${errorStack}`);
  }

  public addErrorListener(listener: (error: Error, context?: string) => void): void {
    this.errorListeners.push(listener);
  }

  public removeErrorListener(listener: (error: Error, context?: string) => void): void {
    this.errorListeners = this.errorListeners.filter(l => l !== listener);
  }

  public wrapFunction(func: () => void, context: string): () => void {
    const self = this;
    return (): void => {
      try {
        func();
      } catch (error) {
        self.handleError(error as Error, context);
      }
    };
  }
}
