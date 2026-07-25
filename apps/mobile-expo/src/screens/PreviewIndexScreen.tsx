import { useState } from 'react';
import { ScrollView, Text, View } from 'react-native';
import type {} from 'uniwind/types';
import { Uniwind, useUniwind } from 'uniwind';
import { BottomSheet } from 'heroui-native/bottom-sheet';
import { Button, type ButtonVariant } from 'heroui-native/button';
import { Card } from 'heroui-native/card';
import { Chip } from 'heroui-native/chip';
import { Description } from 'heroui-native/description';
import { Input } from 'heroui-native/input';
import { Label } from 'heroui-native/label';
import { Switch } from 'heroui-native/switch';
import { TextField } from 'heroui-native/text-field';

const buttonVariants: ButtonVariant[] = [
  'primary',
  'secondary',
  'tertiary',
  'outline',
  'ghost',
  'danger',
  'danger-soft',
];

export function PreviewIndexScreen() {
  const { theme } = useUniwind();
  const [isEnabled, setIsEnabled] = useState(true);
  const [note, setNote] = useState('');
  const [isSheetOpen, setIsSheetOpen] = useState(false);
  const isDark = theme === 'dark';

  const toggleTheme = () => {
    Uniwind.setTheme(isDark ? 'light' : 'dark');
  };

  return (
    <View className="flex-1 bg-background">
      <ScrollView
        contentContainerStyle={{
          gap: 16,
          paddingBottom: 48,
          paddingHorizontal: 20,
          paddingTop: 20,
        }}
        keyboardShouldPersistTaps="handled"
      >
        <View className="gap-2">
          <Text className="text-2xl font-semibold text-foreground">
            HeroUI Native 1.0.6
          </Text>
          <Text className="text-sm text-muted">
            既存画面とは独立した導入可否スパイクです。
          </Text>
          <Button onPress={toggleTheme} variant="outline">
            {isDark ? 'ライトテーマで確認' : 'ダークテーマで確認'}
          </Button>
        </View>

        <Card>
          <Card.Body className="gap-3">
            <Card.Title>Button variants</Card.Title>
            <Card.Description>
              7種類の標準variantとプレスフィードバックを確認します。
            </Card.Description>
            <View className="gap-2">
              {buttonVariants.map((variant) => (
                <Button key={variant} onPress={() => undefined} variant={variant}>
                  {variant}
                </Button>
              ))}
            </View>
          </Card.Body>
        </Card>

        <Card variant="secondary">
          <Card.Body className="gap-3">
            <Card.Title>Form controls</Card.Title>
            <TextField>
              <Label>検証メモ</Label>
              <Input
                onChangeText={setNote}
                placeholder="日本語入力とフォーカスを確認"
                value={note}
              />
              <Description>HeroUI TextField + Input の組み合わせです。</Description>
            </TextField>
            <View className="min-h-11 flex-row items-center justify-between">
              <Text className="text-base text-foreground">HeroUI Switch</Text>
              <Switch isSelected={isEnabled} onSelectedChange={setIsEnabled} />
            </View>
          </Card.Body>
        </Card>

        <Card variant="tertiary">
          <Card.Body className="gap-3">
            <Card.Title>Chip states</Card.Title>
            <View className="flex-row flex-wrap gap-2">
              <Chip color="accent">Accent</Chip>
              <Chip color="success" variant="soft">Success</Chip>
              <Chip color="warning" variant="secondary">Warning</Chip>
              <Chip color="danger" variant="tertiary">Danger</Chip>
            </View>
          </Card.Body>
        </Card>

        <BottomSheet isOpen={isSheetOpen} onOpenChange={setIsSheetOpen}>
          <BottomSheet.Trigger asChild>
            <Button variant="secondary">Bottom Sheet を開く</Button>
          </BottomSheet.Trigger>
          <BottomSheet.Portal>
            <BottomSheet.Overlay />
            <BottomSheet.Content>
              <BottomSheet.Close />
              <View className="gap-2 pb-6">
                <BottomSheet.Title>HeroUI BottomSheet</BottomSheet.Title>
                <BottomSheet.Description>
                  @gorhom/bottom-sheet、Gesture Handler、HeroUI Portalの共存確認です。
                </BottomSheet.Description>
              </View>
              <Button onPress={() => setIsSheetOpen(false)}>閉じる</Button>
            </BottomSheet.Content>
          </BottomSheet.Portal>
        </BottomSheet>
      </ScrollView>
    </View>
  );
}
