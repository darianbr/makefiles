<?php

declare(strict_types=1);

namespace Tests;

use PHPUnit\Framework\TestCase;

final class HelloWorldTest extends TestCase
{
    public function testSaysHello(): void
    {
        self::assertSame('Hello, world!', 'Hello, world!');
    }
}
