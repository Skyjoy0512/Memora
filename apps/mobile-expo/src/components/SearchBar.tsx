import { Pressable, StyleSheet, TextInput, View } from 'react-native';
import { AppIcon } from './AppIcon';
import { colors, radius, spacing } from '../design/tokens';

type SearchBarProps = {
  value: string;
  onChangeText: (text: string) => void;
  placeholder?: string;
  onFocus?: () => void;
  onBlur?: () => void;
};

export function SearchBar({
  value,
  onChangeText,
  placeholder = '記録を検索',
  onFocus,
  onBlur,
}: SearchBarProps) {
  return (
    <View style={searchBarStyles.container}>
      <AppIcon color={colors.textTertiary} name="search-outline" size={16} />
      <TextInput
        accessibilityLabel="記録を検索"
        clearButtonMode="while-editing"
        onChangeText={onChangeText}
        onFocus={onFocus}
        onBlur={onBlur}
        placeholder={placeholder}
        placeholderTextColor={colors.textTertiary}
        returnKeyType="search"
        style={searchBarStyles.input}
        value={value}
      />
      {value.length > 0 ? (
        <Pressable
          accessibilityLabel="検索をクリア"
          accessibilityRole="button"
          hitSlop={8}
          onPress={() => onChangeText('')}
          style={({ pressed }) => [
            searchBarStyles.clearButton,
            pressed && searchBarStyles.pressed,
          ]}
        >
          <AppIcon color={colors.textTertiary} name="close" size={16} />
        </Pressable>
      ) : null}
    </View>
  );
}

const searchBarStyles = StyleSheet.create({
  container: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radius.sm,
    borderWidth: 1,
    flexDirection: 'row',
    gap: spacing.sm,
    minHeight: 44,
    paddingHorizontal: spacing.md,
  },
  input: {
    color: colors.text,
    flex: 1,
    fontSize: 15,
    minHeight: 44,
    paddingVertical: spacing.xs,
  },
  clearButton: {
    alignItems: 'center',
    height: 28,
    justifyContent: 'center',
    width: 28,
  },
  pressed: {
    opacity: 0.6,
  },
});
