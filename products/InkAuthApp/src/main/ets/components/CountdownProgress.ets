// CountdownProgress.ets

@Component
export struct CountdownProgress {
  @Prop progress: number;
  @Prop isDarkMode: boolean;

  build() {
    Stack() {
      Text('')
        .width('100%')
        .height(2)
        .backgroundColor(this.isDarkMode ? '#616161' : '#E0E0E0')
        .borderRadius(1)
      Text('')
        .width(`${this.progress}%`)
        .height(2)
        .backgroundColor('#3F51B5')
        .borderRadius(1)
    }
  }
}
