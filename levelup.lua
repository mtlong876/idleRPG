local levelupTable = {
    0, 100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500,
    5500, 6600, 7800, 9100, 10500, 12000, 13600, 15300, 17100, 19000,
}
for k,v in pairs(levelupTable) do
    print(k,v)  -- Double the experience required for each level
end
return levelupTable