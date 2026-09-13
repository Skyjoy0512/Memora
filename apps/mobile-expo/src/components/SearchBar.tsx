import { useState } from 'react';
import { Pressable, StyleSheet, TextInput, View } from 'react-native';
import { AppIcon } from './AppIcon';
import { colors, spacing, textStyles } from '../design/tokens';

type SearchBarProps = {
  value: string;
  onChangeText: (text: string) => void;
  placeholder?: string;
  onFocus?: () => void;
  onBlur?: () => void;
};

/**
 * Open Design v2 の `.search-field`。角丸なし・1px 枠・44pt 高で、
 * フォーカス時だけ枠が前景色へ寄る。ヘッダーに常設する前提の見た目。
 */
export function SearchBar({
  value,
  onChangeText,
  placeholder = '記録を検索',
  onFocus,
  onBlur,
}: SearchBarProps) {
  const [isFocused, setIsFocused] = useState(false);

  return (
    <View style={[styles.field, isFocused && styles.fieldFocused]}>
      <AppIcon
        color={isFocused ? colors.text : colors.textSecondary}
        name="search-outline"
        size={20}
        style={styles.icon}
      />
      <TextInput
        accessibilityLabel={placeholder}
        onBlur={() => {
          setIsFocused(false);
          onBlur?.();
        }}
        onChangeText={onChangeText}
        onFocus={() => {
          setIsFocused(true);
          onFocus?.();
        }}
        placeholder={placeholder}
        placeholderTextColor={colors.accentMuted}
        returnKeyType="search"
        style={styles.input}
        value={value}
      />
      {value ? (
        <Pressable
          accessibilityLabel="検索をクリア"
          accessibilityRole="button"
          hitSlop={8}
          onPress={() => onChangeText('')}
          style={styles.clear}
        >
          <AppIcon color={colors.textSecondary} name="close" size={16} />
        </Pressable>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  field: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 0,
    borderWidth: 1,
    flexDirection: 'row',
    height: 44,
    paddingHorizontal: spacing.sm,
  },
  fieldFocused: {
    borderColor: colors.text,
  },
  icon: {
    flexShrink: 0,
  },
  input: {
    color: colors.text,
    flex: 1,
    paddingHorizontal: spacing.sm,
    paddingVertical: 0,
    ...textStyles.footnote,
  },
  clear: {
    alignItems: 'center',
    height: 28,
    justifyContent: 'center',
    width: 28,
  },
});
