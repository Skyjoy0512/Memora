import { SearchField } from 'heroui-native/search-field';
import { colors } from '../design/tokens';

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
    <SearchField onChange={onChangeText} value={value}>
      <SearchField.Group>
        <SearchField.SearchIcon iconProps={{ color: colors.textTertiary, size: 16 }} />
        <SearchField.Input
          accessibilityLabel="記録を検索"
          onBlur={onBlur}
          onFocus={onFocus}
          placeholder={placeholder}
          returnKeyType="search"
        />
        <SearchField.ClearButton accessibilityLabel="検索をクリア" />
      </SearchField.Group>
    </SearchField>
  );
}
