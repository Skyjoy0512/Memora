import { StyleSheet } from 'react-native';
import { SearchField } from 'heroui-native';

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
    <SearchField onChange={onChangeText} style={searchBarStyles.container} value={value}>
      <SearchField.Group>
        <SearchField.SearchIcon />
        <SearchField.Input
        accessibilityLabel="記録を検索"
        clearButtonMode="while-editing"
        onFocus={onFocus}
        onBlur={onBlur}
        placeholder={placeholder}
        />
        <SearchField.ClearButton
          accessibilityLabel="検索をクリア"
        />
      </SearchField.Group>
    </SearchField>
  );
}

const searchBarStyles = StyleSheet.create({
  container: {
    minHeight: 44,
  },
});
