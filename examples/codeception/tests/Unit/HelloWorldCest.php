<?php

declare(strict_types=1);

namespace Tests\Unit;

final class HelloWorldCest
{
    public function saysHello(\UnitTester $I): void
    {
        $I->assertSame('Hello, world!', 'Hello, world!');
    }
}
