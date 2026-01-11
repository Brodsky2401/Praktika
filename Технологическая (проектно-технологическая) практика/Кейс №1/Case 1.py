def sum_negative_between_min_max(arr):
    min_index = arr.index(min(arr))
    max_index = arr.index(max(arr))

    start = min(min_index, max_index) + 1
    end = max(min_index, max_index)

    return sum(x for x in arr[start:end] if x < 0)


A = [3, -2, 5, -7, -4, -1, 9]
print(sum_negative_between_min_max(A))
